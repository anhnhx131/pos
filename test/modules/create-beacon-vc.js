#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import {fileURLToPath} from 'url';
import {
  DEFAULT_TEST_DIR,
  loadDeploymentContext,
  buildVmOptions,
  createGcpVm,
  getInstanceExternalIp,
  buildEnvContent,
  DEFAULT_VALIDATOR_PASSWORD,
  REPO_URL,
  REPO_BRANCH,
} from '../lib/gcpHelpers.js';
import {DEFAULT_REMOTE_ENV} from '../config/defaultRemoteEnv.js';

const BEACON_NODE_TCP_PORTS = [22, 3500, 9000, 9001, 8545, 8546, 30303];
const BEACON_NODE_UDP_PORTS = [30303, 9000, 9001];

function buildBeaconNodeStartupScript({validatorPassword, validatorKeyJson, envOverrides = {}}) {
  const envContent = buildEnvContent({
    ...DEFAULT_REMOTE_ENV,
    ...envOverrides,
    VALIDATOR_KEY_JSON: validatorKeyJson,
    VALIDATOR_KEY_PASSWORD: validatorPassword || DEFAULT_VALIDATOR_PASSWORD,
  });
  const password = validatorPassword || DEFAULT_VALIDATOR_PASSWORD;
  return `#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y 2>&1 | tee -a /var/log/startup-script.log
apt-get install -y ca-certificates curl gnupg lsb-release git 2>&1 | tee -a /var/log/startup-script.log
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y 2>&1 | tee -a /var/log/startup-script.log
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>&1 | tee -a /var/log/startup-script.log
systemctl enable docker 2>&1 | tee -a /var/log/startup-script.log
systemctl start docker 2>&1 | tee -a /var/log/startup-script.log
docker --version 2>&1 | tee -a /var/log/startup-script.log
docker compose version 2>&1 | tee -a /var/log/startup-script.log

INSTANCE_NAME=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
NODE_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip || echo "N/A")

mkdir -p /data
apt-get install -y -qq git curl wget jq
cd /data
if [ -d "pos" ]; then
  cd pos
  git fetch origin
  git checkout ${REPO_BRANCH}
  git reset --hard origin/${REPO_BRANCH}
else
  git clone ${REPO_URL} pos
  cd pos
  git checkout ${REPO_BRANCH}
fi
git fetch origin
git checkout ${REPO_BRANCH}
git reset --hard origin/${REPO_BRANCH}
chmod +x /data/pos/*.sh /data/pos/modules/**/*.sh 2>/dev/null || true

cd /data/pos
if [ -d "test/validator_keys" ]; then
  mkdir -p data/cl/validator/validator_keys
  cp -r test/validator_keys/* data/cl/validator/validator_keys/ 2>/dev/null || true
  echo "${password}" > data/cl/validator/validator_keys/password.txt
  chmod 600 data/cl/validator/validator_keys/password.txt
fi

cat > .env.beacon <<'ENVEOF'
${envContent}
ENVEOF
echo "NODE_IP=$NODE_IP" >> .env.beacon
./start.sh beacon-vc .env.beacon 2>&1 | tee -a /var/log/startup-script.log

echo "=== Startup script completed ===" | tee -a /var/log/startup-script.log
date | tee -a /var/log/startup-script.log
`;
}

function getArgValue(flag) {
  const prefixed = `${flag}=`;
  for (const arg of process.argv.slice(2)) {
    if (arg.startsWith(prefixed)) {
      return arg.slice(prefixed.length);
    }
  }
  const idx = process.argv.indexOf(flag);
  if (idx !== -1 && idx + 1 < process.argv.length) {
    return process.argv[idx + 1];
  }
  return null;
}

function resolveNumeric(value, fallback) {
  if (value === undefined || value === null) return fallback;
  const num = Number(value);
  return Number.isFinite(num) ? num : fallback;
}

export async function createBeaconCluster({poaEnode, bootnodeEnr, validatorCount, context} = {}) {
  const effectiveContext = context || loadDeploymentContext();
  const effectivePoaEnode = poaEnode || process.env.POA_ENODE || getArgValue('--poa-enode');
  const effectiveBootnodeEnr = bootnodeEnr || process.env.BOOTNODE_ENR || getArgValue('--bootnode-enr');
  if (!effectivePoaEnode) {
    throw new Error('Missing POA enode. Provide via POA_ENODE env or --poa-enode flag.');
  }
  if (!effectiveBootnodeEnr) {
    throw new Error('Missing bootnode ENR. Provide via BOOTNODE_ENR env or --bootnode-enr flag.');
  }

  const desiredCount = resolveNumeric(
    validatorCount ?? process.env.VALIDATOR_COUNT ?? getArgValue('--validator-count'),
    10,
  );

  const validatorDir = path.join(DEFAULT_TEST_DIR, 'validator_keys');
  const allFiles = fs.readdirSync(validatorDir);
  const keystoreFiles = allFiles.filter((f) => f.startsWith('keystore-') && f.endsWith('.json'));
  if (!keystoreFiles.length) {
    throw new Error(`No keystore files found in ${validatorDir}`);
  }

  const selected = keystoreFiles.slice(0, desiredCount);
  const nodes = [];
  for (let i = 0; i < selected.length; i += 1) {
    const file = selected[i];
    const keystorePath = path.join(validatorDir, file);
    console.log(`[create-beacon-vc] Using keystore ${file} at ${keystorePath}`);
    const validatorKeyJson = fs.readFileSync(keystorePath, 'utf8').trim();

    const vmName = `beacon-validator-node-${i}`;
    console.log(`[create-beacon-vc] Creating beacon node VM "${vmName}"...`);
    const beaconInstance = await createGcpVm({
      ...buildVmOptions(effectiveContext, vmName),
      machineType: 'e2-medium',
      bootDiskSize: '30GB',
      startupScriptBuilder: (opts) =>
        buildBeaconNodeStartupScript({
          ...opts,
          validatorPassword: DEFAULT_VALIDATOR_PASSWORD,
          validatorKeyJson: `'${validatorKeyJson}'`,
          envOverrides: {
            EL_BOOTNODES: effectivePoaEnode,
            CL_BOOTNODE_ENR: effectiveBootnodeEnr,
            ...(effectiveContext?.envOverrides?.beacon || {}),
          },
        }),
      tcpPorts: BEACON_NODE_TCP_PORTS,
      udpPorts: BEACON_NODE_UDP_PORTS,
    });

    const beaconIp = getInstanceExternalIp(beaconInstance);
    if (beaconIp) {
      console.log(`[create-beacon-vc] Beacon node "${vmName}" External IP: ${beaconIp}`);
    }
    nodes.push({name: vmName, ip: beaconIp || null});
  }

  return {nodes};
}

const executedDirectly = process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
if (executedDirectly) {
  createBeaconCluster()
    .then(() => {
      console.log('[create-beacon-vc] Completed');
    })
    .catch((err) => {
      console.error('[create-beacon-vc] Failed:', err);
      process.exit(1);
    });
}
