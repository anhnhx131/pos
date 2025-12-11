#!/usr/bin/env node
import path from 'path';
import {fileURLToPath} from 'url';
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

const DORA_NODE_TCP_PORTS = [22, 8080, 80];
const DORA_NODE_UDP_PORTS = [];

function buildDoraStartupScript({envOverrides = {}}) {
  const envContent = buildEnvContent({...DEFAULT_REMOTE_ENV, ...envOverrides, COMPOSE_FILE: 'dora.yml'});
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
cat > .env.dora <<'ENVEOF'
${envContent}
ENVEOF
./start.sh dora .env.dora 2>&1 | tee -a /var/log/startup-script.log

echo "=== Startup script completed ===" | tee -a /var/log/startup-script.log
date | tee -a /var/log/startup-script.log
`;
}

export async function createDoraNode({context, clRpcUrl, elRpcUrl} = {}) {
  const effectiveContext = context || loadDeploymentContext();
  const doraInstance = await createGcpVm({
    ...buildVmOptions(effectiveContext, 'dora-explorer'),
    machineType: 'e2-medium',
    bootDiskSize: '30GB',
    startupScriptBuilder: (params) =>
      buildDoraStartupScript({
        ...params,
        envOverrides: {
          DORA_CL_RPC_URL: clRpcUrl,
          DORA_EL_RPC_URL: elRpcUrl,
        }
      }),
    tcpPorts: DORA_NODE_TCP_PORTS,
    udpPorts: DORA_NODE_UDP_PORTS,
  });

  const doraIp = getInstanceExternalIp(doraInstance);
  if (doraIp) {
    console.log(`[create-dora] Dora explorer External IP: ${doraIp}`);
  }
  console.log('[create-dora] Deployment initiated. Check /var/log/startup-script.log on the VM for progress.');
  return {doraIp: doraIp || null};
}

const executedDirectly = process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
if (executedDirectly) {
  createDoraNode()
    .then(() => {
      console.log('[create-dora] Completed');
    })
    .catch((err) => {
      console.error('[create-dora] Failed:', err);
      process.exit(1);
    });
}
