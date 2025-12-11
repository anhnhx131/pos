#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import {fileURLToPath} from 'url';
import {
  InstancesClient,
  FirewallsClient,
  ZoneOperationsClient,
  NetworksClient,
  GlobalOperationsClient,
} from '@google-cloud/compute';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
// Point to test root directory (one level up from lib)
export const DEFAULT_TEST_DIR = path.resolve(__dirname, '..');
export const DEFAULT_SSH_KEY_BASENAME = path.join(DEFAULT_TEST_DIR, '.ssh', 'gcp_demo');
export const DEFAULT_SERVICE_ACCOUNT_KEY = path.join(DEFAULT_TEST_DIR, 'gcp-service-key.json');
export const DEFAULT_ZONE = 'asia-northeast1-a';
export const DEFAULT_SSH_USER = 'linux';
export const REPO_URL = 'https://github.com/anhnhx131/pos.git';
export const REPO_BRANCH = 'eth-docker';
export const DEFAULT_VALIDATOR_PASSWORD = 'password@123';

let clientsCache;

export function buildEnvContent(envObject) {
  return Object.entries(envObject)
    .map(([key, value]) => `${key}=${value ?? ''}`)
    .join('\n')
    .concat('\n');
}

export function loadDeploymentContext() {
  console.log('[context] Loading service account config...');
  const serviceAccountConfig = JSON.parse(fs.readFileSync(DEFAULT_SERVICE_ACCOUNT_KEY, 'utf8'));
  const context = {
    projectId: serviceAccountConfig.project_id,
    serviceAccountEmail: serviceAccountConfig.client_email,
    serviceAccountKeyPath: DEFAULT_SERVICE_ACCOUNT_KEY,
    zone: process.env.GCP_ZONE || DEFAULT_ZONE,
    sshUser: process.env.GCP_SSH_USER || DEFAULT_SSH_USER,
    sshPrivateKeyPath: process.env.GCP_SSH_KEY || DEFAULT_SSH_KEY_BASENAME,
    envOverrides: {},
  };
  console.log(`[context] Project ID: ${context.projectId}`);
  return context;
}

export function buildVmOptions(context, name, overrides = {}) {
  return {
    projectId: context.projectId,
    zone: context.zone || DEFAULT_ZONE,
    name,
    serviceAccount: context.serviceAccountEmail,
    serviceAccountKeyPath: context.serviceAccountKeyPath,
    ...overrides,
  };
}

export function getInstanceExternalIp(instance) {
  return (
    instance?.networkInterfaces?.[0]?.accessConfigs?.[0]?.natIP ||
    instance?.networkInterfaces?.[0]?.accessConfigs?.[0]?.externalIp ||
    ''
  );
}

async function getComputeClients(serviceAccountKeyPath) {
  const cacheKey = serviceAccountKeyPath || 'default';
  if (clientsCache && clientsCache.key === cacheKey) {
    return clientsCache.clients;
  }
  const clientOptions = serviceAccountKeyPath ? {keyFilename: serviceAccountKeyPath} : {};
  const instancesClient = new InstancesClient(clientOptions);
  const firewallsClient = new FirewallsClient(clientOptions);
  const zoneOperationsClient = new ZoneOperationsClient(clientOptions);
  const networksClient = new NetworksClient(clientOptions);
  const globalOperationsClient = new GlobalOperationsClient(clientOptions);
  clientsCache = {key: cacheKey, clients: {instancesClient, firewallsClient, zoneOperationsClient, networksClient, globalOperationsClient}};
  return clientsCache.clients;
}

async function ensureNetwork({projectId, networkName, serviceAccountKeyPath}) {
  console.log(`[ensureNetwork] Checking network: ${networkName}`);
  const {networksClient, globalOperationsClient} = await getComputeClients(serviceAccountKeyPath);
  try {
    await networksClient.get({project: projectId, network: networkName});
    console.log(`[ensureNetwork] Network already exists: ${networkName}`);
    return;
  } catch (err) {
    const notFound =
      err?.code === 5 || err?.code === 404 || (typeof err?.message === 'string' && err.message.toLowerCase().includes('not found'));
    if (!notFound) throw err;
  }

  console.log(`[ensureNetwork] Creating network: ${networkName}`);
  const [operation] = await networksClient.insert({
    project: projectId,
    networkResource: {
      name: networkName,
      autoCreateSubnetworks: true,
    },
  });
  const operationName = operation.latestResponse.name;
  while (true) {
    const [op] = await globalOperationsClient.get({project: projectId, operation: operationName});
    if (op.status === 'DONE') {
      if (op.error && op.error.errors && op.error.errors.length) {
        const message = op.error.errors.map((e) => e.message).join(', ');
        throw new Error(`Network creation error: ${message}`);
      }
      console.log(`[ensureNetwork] Network created successfully: ${networkName}`);
      break;
    }
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
}

async function ensureFirewallRule({projectId, ruleName, network, networkTag, tcpPorts, udpPorts, serviceAccountKeyPath}) {
  console.log(`[ensureFirewallRule] Checking firewall rule: ${ruleName}`);
  const {firewallsClient} = await getComputeClients(serviceAccountKeyPath);
  const allow = [];
  if (tcpPorts.length) {
    allow.push({IPProtocol: 'tcp', ports: tcpPorts.map((port) => String(port))});
  }
  if (udpPorts.length) {
    allow.push({IPProtocol: 'udp', ports: udpPorts.map((port) => String(port))});
  }
  try {
    await firewallsClient.get({project: projectId, firewall: ruleName});
    console.log('[ensureFirewallRule] Firewall rule already exists');
    return;
  } catch (err) {
    const notFound =
      err?.code === 5 || err?.code === 404 || (typeof err?.message === 'string' && err.message.toLowerCase().includes('not found'));
    if (!notFound) throw err;
  }

  console.log(`[ensureFirewallRule] Creating firewall rule: ${ruleName}`);
  await firewallsClient.insert({
    project: projectId,
    firewallResource: {
      name: ruleName,
      network: `projects/${projectId}/global/networks/${network}`,
      targetTags: [networkTag],
      allowed: allow,
    },
  });
  console.log('[ensureFirewallRule] Firewall rule created');
}

async function waitForZonalOperation(zoneOperationsClient, projectId, zone, operationName) {
  console.log(`[waitForZonalOperation] Waiting for operation: ${operationName}`);
  let finished = false;
  let attempts = 0;
  while (!finished) {
    attempts += 1;
    const [operation] = await zoneOperationsClient.get({project: projectId, zone, operation: operationName});
    console.log(`[waitForZonalOperation] Attempt ${attempts}: status=${operation.status}`);
    if (operation.status === 'DONE') {
      if (operation.error && operation.error.errors && operation.error.errors.length) {
        const message = operation.error.errors.map((e) => e.message).join(', ');
        throw new Error(`Operation error: ${message}`);
      }
      finished = true;
      console.log('[waitForZonalOperation] Operation completed successfully');
    } else {
      await new Promise((resolve) => setTimeout(resolve, 3000));
    }
  }
}

const DEFAULT_TCP_PORTS = [22, 8545, 3500, 9000, 8080, 30303];
const DEFAULT_UDP_PORTS = [9000, 30303];

export async function createGcpVm(options = {}) {
  const {
    projectId,
    zone = DEFAULT_ZONE,
    name,
    machineType = 'e2-medium',
    imageFamily = 'debian-12',
    imageProject = 'debian-cloud',
    bootDiskSize = '30GB',
    sshUser = DEFAULT_SSH_USER,
    sshPublicKeyPath = `${DEFAULT_SSH_KEY_BASENAME}.pub`,
    serviceAccountKeyPath = DEFAULT_SERVICE_ACCOUNT_KEY,
    startupScriptBuilder,
    network,
    networkTag,
    tcpPorts = DEFAULT_TCP_PORTS,
    udpPorts = DEFAULT_UDP_PORTS,
    serviceAccount,
    useServiceKeyForAuth = true,
  } = options;

  if (!projectId || !zone || !name) {
    throw new Error('projectId, zone, and name are required to create a VM');
  }

  const nodeNetwork = network || `${name}-network`;
  const nodeNetworkTag = networkTag || `${name}-tag`;

  await ensureNetwork({
    projectId,
    networkName: nodeNetwork,
    serviceAccountKeyPath: useServiceKeyForAuth ? serviceAccountKeyPath : undefined,
  });

  const {instancesClient, zoneOperationsClient} = await getComputeClients(
    useServiceKeyForAuth ? serviceAccountKeyPath : undefined,
  );

  const sshKey = fs.readFileSync(sshPublicKeyPath, 'utf8').trim();
  const startupScript = startupScriptBuilder
    ? startupScriptBuilder({sshUser, sshKey})
    : buildCommonStartupScript({sshUser, sshKey, deployType: 'none', envContent: ''});

  const machineTypeUri = `projects/${projectId}/zones/${zone}/machineTypes/${machineType}`;
  const sourceImage = `projects/${imageProject}/global/images/family/${imageFamily}`;
  const diskSizeGb = parseInt(String(bootDiskSize).replace(/[^0-9]/g, ''), 10);
  const networkUri = `projects/${projectId}/global/networks/${nodeNetwork}`;

  const instanceResource = {
    name,
    machineType: machineTypeUri,
    disks: [
      {
        boot: true,
        autoDelete: true,
        initializeParams: {sourceImage, diskSizeGb},
      },
    ],
    metadata: {
      items: [
        {key: 'startup-script', value: startupScript},
        {key: 'ssh-keys', value: `${sshUser}:${sshKey}`},
      ],
    },
    networkInterfaces: [
      {
        network: networkUri,
        accessConfigs: [{name: 'External NAT', type: 'ONE_TO_ONE_NAT'}],
      },
    ],
    tags: {items: [nodeNetworkTag]},
  };

  if (serviceAccount) {
    instanceResource.serviceAccounts = [
      {
        email: serviceAccount,
        scopes: ['https://www.googleapis.com/auth/cloud-platform'],
      },
    ];
  }

  console.log(`[createGcpVm] Inserting instance ${name}...`);
  const [operation] = await instancesClient.insert({project: projectId, zone, instanceResource});
  await waitForZonalOperation(zoneOperationsClient, projectId, zone, operation.latestResponse.name);

  await ensureFirewallRule({
    projectId,
    ruleName: `${name}-firewall`,
    network: nodeNetwork,
    networkTag: nodeNetworkTag,
    tcpPorts,
    udpPorts,
    serviceAccountKeyPath: useServiceKeyForAuth ? serviceAccountKeyPath : undefined,
  });

  const [instance] = await instancesClient.get({project: projectId, zone, instance: name});
  return instance;
}

export function buildCommonStartupScript({
  deployType,
  validatorPassword = DEFAULT_VALIDATOR_PASSWORD,
  envContent
}) {
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

# Setup Google Cloud Ops Agent for Docker logs
echo "=== Setting up Google Cloud Ops Agent ===" | tee -a /var/log/startup-script.log
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh 2>&1 | tee -a /var/log/startup-script.log
bash add-google-cloud-ops-agent-repo.sh --also-install 2>&1 | tee -a /var/log/startup-script.log

# Configure Ops Agent to collect Docker logs
cat << 'OPSAGENTEOF' > /etc/google-cloud-ops-agent/config.yaml
logging:
  receivers:
    docker_logs:
      type: files
      include_paths:
        - /var/lib/docker/containers/*/*-json.log
  service:
    pipelines:
      default_pipeline:
        receivers: [docker_logs]
metrics:
  receivers:
    hostmetrics:
      type: hostmetrics
  service:
    pipelines:
      default_pipeline:
        receivers: [hostmetrics]
OPSAGENTEOF

# Configure Docker to use json-file log driver
mkdir -p /etc/docker
cat << 'DOCKERCONFEOF' > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "5" }
}
DOCKERCONFEOF

systemctl restart docker 2>&1 | tee -a /var/log/startup-script.log
systemctl restart google-cloud-ops-agent 2>&1 | tee -a /var/log/startup-script.log
echo "=== Google Cloud Ops Agent setup completed ===" | tee -a /var/log/startup-script.log

INSTANCE_NAME=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
NODE_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip || echo "N/A")
INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
ZONE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | sed 's/.*\\///')
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

if [ -z "\${NODE_IP:-}" ] || [ "\${NODE_IP:-}" = "N/A" ]; then
  echo "Error: NODE_IP is not set" | tee -a /var/log/startup-script.log
  exit 1
fi

# Use a single env file for all deploy types
cat > .env.joc <<'ENVEOF'
${envContent}
ENVEOF
echo "NODE_IP=\${NODE_IP}" >> .env.joc

if [ \"${deployType}\" = "beacon" ]; then
  if [ -d "test/validator_keys" ]; then
    mkdir -p data/cl/validator/validator_keys
    cp -r test/validator_keys/* data/cl/validator/validator_keys/ 2>/dev/null || true
    echo "\${validatorPassword}" > data/cl/validator/validator_keys/password.txt
    chmod 600 data/cl/validator/validator_keys/password.txt
  fi
fi

if [ \"${deployType}\" = "blockscout" ]; then
  # Replace NODE_IP placeholder in env file with actual IP
  sed -i "s|\\\${NODE_IP}|\${NODE_IP}|g" .env.joc
fi

./start.sh ${deployType} .env.joc 2>&1 | tee -a /var/log/startup-script.log

echo "=== Startup script completed ===" | tee -a /var/log/startup-script.log
date | tee -a /var/log/startup-script.log
`;
}
