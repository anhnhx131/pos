#!/usr/bin/env node
import path from 'path';
import {fileURLToPath} from 'url';
import axios from 'axios';
import {
  loadDeploymentContext,
  buildVmOptions,
  createGcpVm,
  getInstanceExternalIp,
  buildEnvContent,
  REPO_URL,
  REPO_BRANCH,
} from '../lib/gcpHelpers.js';
import {DEFAULT_REMOTE_ENV} from '../config/defaultRemoteEnv.js';

const BEACON_TCP_PORTS = [22, 3500, 9000, 9001, 8545, 8546, 30303];
const BEACON_UDP_PORTS = [30303, 9000, 9001];

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

function buildBeaconStartupScript({poaEnode, bootnodeEnr, envOverrides = {}}) {
  const envContent = buildEnvContent({...DEFAULT_REMOTE_ENV, ...envOverrides});
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
cat > .env.beacon <<'ENVEOF'
${envContent}
ENVEOF
echo "NODE_IP=$NODE_IP" >> .env.beacon

log() {
  echo "[beacon-startup] $1" | tee -a /var/log/startup-script.log
}

log "Starting beacon stack (execution + consensus)..."
./start.sh beacon .env.beacon 2>&1 | tee -a /var/log/beacon-stack.log

log "Startup script completed"
date | tee -a /var/log/startup-script.log
`;
}

async function waitForCliqueEnode(host, {timeoutMs = 300000, pollIntervalMs = 2000} = {}) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const response = await axios.post(`http://${host}:8545`, {
        jsonrpc: '2.0',
        method: 'admin_nodeInfo',
        params: [],
        id: 1,
      });
      const enode = response?.data?.result?.enode;
      if (enode) {
        return enode;
      }
    } catch (error) {
      // retry
    }
    await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
  }
  throw new Error('Timed out waiting for clique enode');
}

export async function initBeacon({poaEnode, bootnodeEnr, context} = {}) {
  const effectivePoaEnode = poaEnode || process.env.POA_ENODE || getArgValue('--poa-enode');
  const effectiveBootnodeEnr = bootnodeEnr || process.env.BOOTNODE_ENR || getArgValue('--bootnode-enr');
  if (!effectivePoaEnode) {
    throw new Error('Missing POA enode. Provide via POA_ENODE env or --poa-enode flag.');
  }
  if (!effectiveBootnodeEnr) {
    throw new Error('Missing bootnode ENR. Provide via BOOTNODE_ENR env or --bootnode-enr flag.');
  }
  const effectiveContext = context || loadDeploymentContext();

  const beaconInstance = await createGcpVm({
    ...buildVmOptions(effectiveContext, 'beacon-normal-node-1'),
    machineType: 'e2-medium',
    bootDiskSize: '30GB',
    startupScriptBuilder: (params) =>
      buildBeaconStartupScript({
        ...params,
        poaEnode: effectivePoaEnode,
        bootnodeEnr: effectiveBootnodeEnr,
        envOverrides: {
          EL_BOOTNODES: effectivePoaEnode,
          CL_BOOTNODE_ENR: effectiveBootnodeEnr,
          EL_BOOT_NODE_KEY: '31640af736ec4dfef9d776189b3ca4e6d7732d853b815ece7408c9d3c4e10433',
          ...(effectiveContext?.envOverrides?.beacon || {}),
        },
      }),
    tcpPorts: BEACON_TCP_PORTS,
    udpPorts: BEACON_UDP_PORTS,
  });
  console.log('[init-beacon] Beacon VM created successfully');

  const beaconIp = getInstanceExternalIp(beaconInstance);
  if (!beaconIp) {
    throw new Error('Unable to determine beacon external IP');
  }
  console.log(`[init-beacon] Beacon External IP: ${beaconIp}`);

  const beaconEnode = await waitForCliqueEnode(beaconIp, {timeoutMs: 300000, pollIntervalMs: 2000});
  console.log(`[init-beacon] Beacon ENODE: ${beaconEnode}`);

  return {beaconIp, beaconEnode};
}

const executedDirectly = process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
if (executedDirectly) {
  initBeacon()
    .then(() => {
      console.log('[init-beacon] Completed');
    })
    .catch((err) => {
      console.error('[init-beacon] Failed:', err);
      process.exit(1);
    });
}
