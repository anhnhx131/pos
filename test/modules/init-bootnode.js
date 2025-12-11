#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import {fileURLToPath} from 'url';
import SSH2Promise from 'ssh2-promise';
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

const BOOTNODE_TCP_PORTS = [22, 9000, 9001];
const BOOTNODE_UDP_PORTS = [9000, 9001];

function buildBootnodeStartupScript({envOverrides = {}}) {
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
cat > .env.bootnode <<'ENVEOF'
${envContent}
ENVEOF
echo "NODE_IP=$NODE_IP" >> .env.bootnode

log() {
  echo "[bootnode-startup] $1" | tee -a /var/log/startup-script.log
}

log "Starting bootnode service to generate ENR..."
./start.sh bootnode .env.bootnode 2>&1 | tee -a /var/log/startup-script.log

ENR_FILE="/data/pos/.eth/lighthouse/bootnode/beacon/network/enr.dat"
BOOTNODE_ENR=""
MAX_ATTEMPTS=120
SLEEP_SECONDS=2

log "Waiting for ENR at $ENR_FILE"
for attempt in $(seq 1 $MAX_ATTEMPTS); do
  if [ -s "$ENR_FILE" ]; then
    BOOTNODE_ENR=$(tr -d '\\n' < "$ENR_FILE")
    break
  fi
  sleep $SLEEP_SECONDS
done

if [ -z "$BOOTNODE_ENR" ]; then
  log "Failed to obtain ENR after waiting $MAX_ATTEMPTS attempts"
else
  TMP_ENV=$(mktemp)
  if [ -f ".env.bootnode" ]; then
    grep -v -e '^CL_BOOTNODE_ENR=' -e '^BOOTNODE_ENR=' .env.bootnode > "$TMP_ENV" || true
  else
    : > "$TMP_ENV"
  fi
  printf 'CL_BOOTNODE_ENR=%s\\n' "$BOOTNODE_ENR" >> "$TMP_ENV"
  printf 'BOOTNODE_ENR=%s\\n' "$BOOTNODE_ENR" >> "$TMP_ENV"
  mv "$TMP_ENV" .env.bootnode
  chmod 644 .env.bootnode
  log "Updated .env.bootnode with ENR"
  log "BOOTNODE_ENR=$BOOTNODE_ENR"
fi

echo "[bootnode-startup] BOOTNODE_ENR=$BOOTNODE_ENR" | tee -a /var/log/startup-script.log
log "Startup script completed"
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

function buildSshConfig(host, context) {
  const keyMaterial = fs.readFileSync(context.sshPrivateKeyPath, 'utf8');
  return {
    host,
    username: context.sshUser,
    privateKey: keyMaterial,
  };
}

async function withSshConnection(sshConfig, fn) {
  const ssh = new SSH2Promise(sshConfig);
  await ssh.connect();
  try {
    return await fn(ssh);
  } finally {
    await ssh.close();
  }
}

async function readBootnodeEnrFromEnv(ssh, {retries = 60, delayMs = 5000} = {}) {
  const envPath = '/data/pos/.env.bootnode';
  for (let attempt = 1; attempt <= retries; attempt += 1) {
    try {
      const content = await ssh.exec(`sudo cat ${envPath} 2>/dev/null || echo ""`);
      const lines = content.split('\n');
      for (const line of lines) {
        if (line.startsWith('BOOTNODE_ENR=')) {
          const enr = line.slice('BOOTNODE_ENR='.length).trim();
          if (enr) {
            return enr;
          }
        }
      }
    } catch (error) {
      // retry
    }
    await new Promise((resolve) => setTimeout(resolve, delayMs));
  }
  throw new Error('Bootnode ENR not found in .env.bootnode after waiting');
}

export async function initBootnode({poaEnode, context} = {}) {
  const effectivePoaEnode = poaEnode || process.env.POA_ENODE || getArgValue('--poa-enode');
  if (!effectivePoaEnode) {
    throw new Error('Missing POA enode. Provide via POA_ENODE env or --poa-enode flag.');
  }
  const effectiveContext = context || loadDeploymentContext();

  const bootnodeInstance = await createGcpVm({
    ...buildVmOptions(effectiveContext, 'bootnode'),
    machineType: 'e2-small',
    bootDiskSize: '20GB',
    startupScriptBuilder: (params) =>
      buildBootnodeStartupScript({
        ...params,
        envOverrides: {
          EL_BOOTNODES: effectivePoaEnode,
          ...(effectiveContext?.envOverrides?.bootnode || {}),
        },
      }),
    tcpPorts: BOOTNODE_TCP_PORTS,
    udpPorts: BOOTNODE_UDP_PORTS,
  });
  console.log('[init-bootnode] Bootnode VM created successfully');

  const bootnodeIp = getInstanceExternalIp(bootnodeInstance);
  if (!bootnodeIp) {
    throw new Error('Unable to determine bootnode external IP');
  }
  console.log(`[init-bootnode] Bootnode External IP: ${bootnodeIp}`);

  // Wait a bit for startup script to complete
  console.log('[init-bootnode] Waiting for startup script to complete and generate ENR...');
  await new Promise((resolve) => setTimeout(resolve, 30000)); // Wait 30 seconds for initial boot

  // SSH and read ENR from .env.bootnode
  const sshConfig = buildSshConfig(bootnodeIp, effectiveContext);
  const bootnodeEnr = await withSshConnection(sshConfig, async (ssh) => {
    console.log('[init-bootnode] Reading ENR from .env.bootnode...');
    return await readBootnodeEnrFromEnv(ssh);
  });
  console.log(`[init-bootnode] Bootnode ENR: ${bootnodeEnr}`);

  return {bootnodeIp, bootnodeEnr};
}

const executedDirectly = process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
if (executedDirectly) {
  initBootnode()
    .then(() => {
      console.log('[init-bootnode] Completed');
    })
    .catch((err) => {
      console.error('[init-bootnode] Failed:', err);
      process.exit(1);
    });
}
