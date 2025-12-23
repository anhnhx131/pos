#!/usr/bin/env node
// Module imports
import {initPoa} from '../modules/init-poa.js';
import {initBootnode} from '../modules/init-bootnode.js';
import {initBeacon} from '../modules/init-beacon.js';
import {createBeaconCluster} from '../modules/create-beacon-vc.js';
import {createDoraNode} from '../modules/create-dora.js';
import {createBlockscoutNode} from '../modules/create-blockscout.js';

// GCP helpers
import {
  loadDeploymentContext,
  buildVmOptions,
  createGcpVm,
  getInstanceExternalIp,
} from './gcpHelpers.js';

// Data management
import {
  getNetwork,
  updateNetworkStep,
  saveNetwork,
  getCurrentNetworkData,
  addNodeToNetwork,
  updateNetworkConfig,
  getDefaultConfig,
} from './dataManager.js';

// Node update helpers
import {
  buildSshConfig,
  updateClique,
  updateBootnode,
  updateBeacon,
  updateBeaconVc,
  updateBlockscout,
} from './nodeUpdateHelper.js';

// External dependencies
import axios from 'axios';

/**
 * Build deployment context from network config
 */
function buildContextFromNetwork(network) {
  const context = loadDeploymentContext();
  
  // Support both old and new config structure
  const config = network.config || {};
  const server = config.server || {};
  const el = config.el || {};
  const cl = config.cl || {};
  
  // Override with network-specific server config
  if (server.projectId || config.projectId) {
    context.projectId = server.projectId || config.projectId;
  }
  if (server.zone || config.zone) {
    context.zone = server.zone || config.zone;
  }
  if (server.sshUser || config.sshUser) {
    context.sshUser = server.sshUser || config.sshUser;
  }
  if (server.sshPrivateKeyPath || config.sshPrivateKeyPath) {
    context.sshPrivateKeyPath = server.sshPrivateKeyPath || config.sshPrivateKeyPath;
  }
  if (config.envOverrides) {
    context.envOverrides = config.envOverrides;
  }
  
  // Add CL config overrides
  if (!context.envOverrides) {
    context.envOverrides = {};
  }
  if (!context.envOverrides.bootnode) {
    context.envOverrides.bootnode = {};
  }
  if (!context.envOverrides.beacon) {
    context.envOverrides.beacon = {};
  }
  
  // Apply CL configs to bootnode and beacon (using env var names directly)
  // First, apply all CL_ prefixed configs from config.cl (new structure)
  Object.keys(cl).forEach(key => {
    if (key.startsWith('CL_')) {
      const value = cl[key];
      if (value !== undefined && value !== null && value !== '') {
        context.envOverrides.bootnode[key] = String(value);
        context.envOverrides.beacon[key] = String(value);
      }
    }
  });
  
  // Backward compatibility: fallback to old mapped keys if env var names not set
  if (!context.envOverrides.bootnode.CL_DEPOSIT_CONTRACT_ADDRESS) {
    const depositContract = cl.depositContractAddress || config.clDepositContractAddress;
    if (depositContract) {
      context.envOverrides.bootnode.CL_DEPOSIT_CONTRACT_ADDRESS = depositContract;
      context.envOverrides.beacon.CL_DEPOSIT_CONTRACT_ADDRESS = depositContract;
    }
  }
  if (!context.envOverrides.bootnode.CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT) {
    const minGenesis = cl.minGenesisActiveValidatorCount !== undefined ? cl.minGenesisActiveValidatorCount : config.clMinGenesisActiveValidatorCount;
    if (minGenesis !== undefined) {
      context.envOverrides.bootnode.CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT = String(minGenesis);
      context.envOverrides.beacon.CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT = String(minGenesis);
    }
  }
  if (!context.envOverrides.bootnode.CL_DEPOSIT_BLOCK) {
    const depositBlock = cl.depositBlock !== undefined ? cl.depositBlock : config.clDepositBlock;
    if (depositBlock !== undefined) {
      context.envOverrides.bootnode.CL_DEPOSIT_BLOCK = String(depositBlock);
      context.envOverrides.beacon.CL_DEPOSIT_BLOCK = String(depositBlock);
    }
  }
  if (!context.envOverrides.bootnode.CL_GENESIS_STATE_URL) {
    const genesisStateUrl = cl.genesisStateUrl || config.clGenesisStateUrl;
    if (genesisStateUrl) {
      context.envOverrides.bootnode.CL_GENESIS_STATE_URL = genesisStateUrl;
      context.envOverrides.beacon.CL_GENESIS_STATE_URL = genesisStateUrl;
    }
  }
  
  return context;
}

/**
 * Get all fork config and CL config that should be applied to new nodes
 * Supports both old structure (mapped keys) and new structure (env var names)
 */
function getNodeForkConfig(network) {
  const forkConfig = {};
  const config = network.config || {};
  const cl = config.cl || {};
  const el = config.el || {};
  
  // NEW STRUCTURE: Direct env var names in config.cl and config.el
  // Apply all CL configs that are env var names (starts with CL_)
  Object.keys(cl).forEach(key => {
    if (key.startsWith('CL_') || key.startsWith('EL_')) {
      const value = cl[key];
      if (value !== undefined && value !== null && value !== '') {
        forkConfig[key] = String(value);
      }
    }
  });
  
  // Apply all EL configs that are env var names (starts with EL_)
  Object.keys(el).forEach(key => {
    if (key.startsWith('CL_') || key.startsWith('EL_')) {
      const value = el[key];
      if (value !== undefined && value !== null && value !== '') {
        forkConfig[key] = String(value);
      }
    }
  });
  
  // OLD STRUCTURE: Support backward compatibility with mapped keys
  // Apply CL configs (backward compatibility)
  const depositContract = cl.depositContractAddress || config.clDepositContractAddress;
  const minGenesis = cl.minGenesisActiveValidatorCount !== undefined ? cl.minGenesisActiveValidatorCount : config.clMinGenesisActiveValidatorCount;
  const depositBlock = cl.depositBlock !== undefined ? cl.depositBlock : config.clDepositBlock;
  const genesisStateUrl = cl.genesisStateUrl || config.clGenesisStateUrl;
  const depositChainId = cl.depositChainId !== undefined ? cl.depositChainId : config.clDepositChainId;
  const depositNetworkId = cl.depositNetworkId !== undefined ? cl.depositNetworkId : config.clDepositNetworkId;
  const secondsPerSlot = cl.secondsPerSlot !== undefined ? cl.secondsPerSlot : config.clSecondsPerSlot;
  const slotsPerEpoch = cl.slotsPerEpoch !== undefined ? cl.slotsPerEpoch : config.clSlotsPerEpoch;
  const secondsPerEth1Block = cl.secondsPerEth1Block !== undefined ? cl.secondsPerEth1Block : config.clSecondsPerEth1Block;
  
  if (depositContract && !forkConfig.CL_DEPOSIT_CONTRACT_ADDRESS) {
    forkConfig.CL_DEPOSIT_CONTRACT_ADDRESS = depositContract;
  }
  if (minGenesis !== undefined && !forkConfig.CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT) {
    forkConfig.CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT = String(minGenesis);
  }
  if (depositBlock !== undefined && !forkConfig.CL_DEPOSIT_BLOCK) {
    forkConfig.CL_DEPOSIT_BLOCK = String(depositBlock);
  }
  if (genesisStateUrl && !forkConfig.CL_GENESIS_STATE_URL) {
    forkConfig.CL_GENESIS_STATE_URL = genesisStateUrl;
  }
  if (depositChainId !== undefined && !forkConfig.CL_DEPOSIT_CHAIN_ID) {
    forkConfig.CL_DEPOSIT_CHAIN_ID = String(depositChainId);
  }
  if (depositNetworkId !== undefined && !forkConfig.CL_DEPOSIT_NETWORK_ID) {
    forkConfig.CL_DEPOSIT_NETWORK_ID = String(depositNetworkId);
  }
  if (secondsPerSlot !== undefined && !forkConfig.CL_SECONDS_PER_SLOT) {
    forkConfig.CL_SECONDS_PER_SLOT = String(secondsPerSlot);
  }
  if (slotsPerEpoch !== undefined && !forkConfig.CL_SLOTS_PER_EPOCH) {
    forkConfig.CL_SLOTS_PER_EPOCH = String(slotsPerEpoch);
  }
  if (secondsPerEth1Block !== undefined && !forkConfig.CL_SECONDS_PER_ETH1_BLOCK) {
    forkConfig.CL_SECONDS_PER_ETH1_BLOCK = String(secondsPerEth1Block);
  }
  
  // Apply EL fork configs (backward compatibility)
  if (el.terminalTotalDifficulty && !forkConfig.EL_TERMINAL_TOTAL_DIFFICULTY) {
    forkConfig.EL_TERMINAL_TOTAL_DIFFICULTY = String(el.terminalTotalDifficulty);
  }
  if (el.shanghaiTime && !forkConfig.EL_SHANGHAI_TIME) {
    forkConfig.EL_SHANGHAI_TIME = String(el.shanghaiTime);
  }
  if (el.cancunTime && !forkConfig.EL_CANCUN_TIME) {
    forkConfig.EL_CANCUN_TIME = String(el.cancunTime);
  }
  if (el.pragueTime && !forkConfig.EL_PRAGUE_TIME) {
    forkConfig.EL_PRAGUE_TIME = String(el.pragueTime);
  }
  if (el.gethImage && !forkConfig.GETH_DOCKER_IMAGE) {
    forkConfig.GETH_DOCKER_IMAGE = el.gethImage;
  }
  
  // Apply CL fork configs (backward compatibility)
  if (cl.terminalTotalDifficulty && !forkConfig.CL_TERMINAL_TOTAL_DIFFICULTY) {
    forkConfig.CL_TERMINAL_TOTAL_DIFFICULTY = String(cl.terminalTotalDifficulty);
  }
  if (cl.capellaForkEpoch !== undefined && !forkConfig.CL_CAPELLA_FORK_EPOCH) {
    forkConfig.CL_CAPELLA_FORK_EPOCH = String(cl.capellaForkEpoch);
  }
  if (cl.denebForkEpoch !== undefined && !forkConfig.CL_DENEB_FORK_EPOCH) {
    forkConfig.CL_DENEB_FORK_EPOCH = String(cl.denebForkEpoch);
  }
  if (cl.electraForkEpoch !== undefined && !forkConfig.CL_ELECTRA_FORK_EPOCH) {
    forkConfig.CL_ELECTRA_FORK_EPOCH = String(cl.electraForkEpoch);
  }
  if (cl.lighthouseImage && !forkConfig.LH_IMAGE) {
    forkConfig.LH_IMAGE = cl.lighthouseImage;
  }
  
  // Apply fork configs (from updateForkForAllNodes - these are already env var names)
  if (config.forkConfig) {
    Object.assign(forkConfig, config.forkConfig);
  }
  
  return forkConfig;
}

/**
 * Execute initPoa step
 */
export async function executeInitPoa(networkName) {
  const network = getNetwork(networkName);
  if (!network) {
    throw new Error(`Network "${networkName}" not found`);
  }

  const context = buildContextFromNetwork(network);
  console.log(`[${networkName}] Starting initPoa...`);
  const result = await initPoa({context});
  updateNetworkStep(networkName, 'initPoa', result);
  console.log(`[${networkName}] initPoa completed:`, result);
  return result;
}

/**
 * Execute initBootnode step - creates bootnode, then automatically creates beacon node and adds to bootnode array
 */
export async function executeInitBootnode(networkName, poaEnode = null) {
  const network = getNetwork(networkName);
  if (!network) {
    throw new Error(`Network "${networkName}" not found`);
  }

  const poaStep = network.steps.initPoa;
  const effectivePoaEnode = poaEnode || (poaStep.status === 'completed' && poaStep.data ? poaStep.data.cliqueEnode : null);
  
  if (!effectivePoaEnode) {
    throw new Error('POA enode is required. Provide poaEnode parameter or complete initPoa step first.');
  }

  const context = buildContextFromNetwork(network);
  
  // Step 1: Create bootnode
  console.log(`[${networkName}] Starting initBootnode...`);
  const bootnodeResult = await initBootnode({
    poaEnode: effectivePoaEnode,
    context,
  });
  updateNetworkStep(networkName, 'initBootnode', bootnodeResult);
  console.log(`[${networkName}] Bootnode created:`, bootnodeResult);

  // Step 2: Automatically create beacon node and add to bootnode array
  console.log(`[${networkName}] Creating beacon node and adding to bootnode array...`);
  const beaconResult = await initBeacon({
    poaEnode: effectivePoaEnode,
    bootnodeEnr: bootnodeResult.bootnodeEnr,
    context,
  });
  
  // Add beacon node to bootnode array (has both enode and enr)
  const beaconNodeData = {
    name: 'beacon-bootnode',
    ip: beaconResult.beaconIp,
    enode: beaconResult.beaconEnode,
    enr: bootnodeResult.bootnodeEnr, // Same ENR for CL
  };
  addNodeToNetwork(networkName, 'bootnode', beaconNodeData);
  console.log(`[${networkName}] Beacon node added to bootnode array:`, beaconNodeData);
  
  console.log(`[${networkName}] initBootnode completed (bootnode + beacon node created)`);
  return {bootnode: bootnodeResult, beacon: beaconResult};
}


/**
 * Execute initBeacon step (deprecated, use executeInitBeaconBootnode instead)
 * @deprecated Use executeInitBeaconBootnode instead
 */
export async function executeInitBeacon(networkName, poaEnode = null, bootnodeEnr = null) {
  return executeInitBeaconBootnode(networkName, poaEnode, bootnodeEnr);
}

/**
 * Create Dora explorer (not a step, just a node)
 */
export async function executeCreateDora(networkName, clRpcUrl = null, elRpcUrl = null) {
  const network = getNetwork(networkName);
  if (!network) {
    throw new Error(`Network "${networkName}" not found`);
  }

  const config = network.config || {};
  const clExplorer = config.clExplorer || getDefaultConfig().clExplorer;
  
  // Try to get from bootnode array (first node should be beacon node)
  const bootnodes = network.nodes?.bootnode || [];
  const firstBootnode = bootnodes.length > 0 ? bootnodes.find(b => b.enode) || bootnodes[0] : null; // Find beacon node (has enode)
  
  // Backward compatibility: try old steps
  const beaconBootnodeStep = network.steps.initBeaconBootnode;
  const beaconStep = network.steps.initBeacon;
  
  let beaconIp = null;
  if (firstBootnode?.ip) {
    beaconIp = firstBootnode.ip;
  } else if (beaconBootnodeStep?.status === 'completed' && beaconBootnodeStep?.data?.beaconIp) {
    beaconIp = beaconBootnodeStep.data.beaconIp;
  } else if (beaconStep?.status === 'completed' && beaconStep?.data?.beaconIp) {
    beaconIp = beaconStep.data.beaconIp;
  }
  
  const effectiveClRpcUrl = clRpcUrl || clExplorer.clRpcUrl || (beaconIp ? `http://${beaconIp}:3500` : null);
  const effectiveElRpcUrl = elRpcUrl || clExplorer.elRpcUrl || (beaconIp ? `http://${beaconIp}:8545` : null);
  
  if (!effectiveClRpcUrl || !effectiveElRpcUrl) {
    throw new Error('CL RPC URL and EL RPC URL are required. Provide parameters or ensure beacon node is available.');
  }

  const context = buildContextFromNetwork(network);
  console.log(`[${networkName}] Creating Dora explorer...`);
  const result = await createDoraNode({
    clRpcUrl: effectiveClRpcUrl,
    elRpcUrl: effectiveElRpcUrl,
    context,
  });
  
  // Update clExplorer config with RPC URLs (no step update)
  updateNetworkConfig(networkName, 'clExplorer', {
    clRpcUrl: effectiveClRpcUrl,
    elRpcUrl: effectiveElRpcUrl,
  });
  
  console.log(`[${networkName}] Dora explorer created:`, result);
  return result;
}

/**
 * Create Blockscout explorer (not a step, just a node)
 */
export async function executeCreateBlockscout(networkName, elRpcUrl = null) {
  const network = getNetwork(networkName);
  if (!network) {
    throw new Error(`Network "${networkName}" not found`);
  }

  const context = buildContextFromNetwork(network);

  const config = network.config || {};
  const elExplorer = config.elExplorer || getDefaultConfig().elExplorer;
  
  const poaStep = network.steps.initPoa;
  // Get clique RPC as default
  const cliqueRpc =
    poaStep.status === 'completed' && poaStep.data ? `http://${poaStep.data.cliqueIp}:8545` : null;
  
  // Priority: explicit parameter > config elRpcUrl (if set) > clique RPC > env var
  let effectiveElRpcUrl = null;
  if (elRpcUrl) {
    effectiveElRpcUrl = elRpcUrl;
  } else if (elExplorer.elRpcUrl && elExplorer.elRpcUrl.trim() !== '') {
    effectiveElRpcUrl = elExplorer.elRpcUrl;
  } else if (cliqueRpc) {
    effectiveElRpcUrl = cliqueRpc;
  } else {
    effectiveElRpcUrl = process.env.EL_RPC_URL || null;
  }
  
  if (!effectiveElRpcUrl) {
    throw new Error('EL RPC URL is required. Provide parameter or ensure POA node is available.');
  }
  
  // Support both old and new config structure
  const el = config.el || {};
  const networkId = elExplorer.networkId || el.networkId || config.networkId || 84;
  const networkNameConfig = elExplorer.networkName || el.networkName || config.networkName || `${networkName} Network`;
  
  console.log(`[${networkName}] Creating Blockscout explorer...`);
  if (cliqueRpc && effectiveElRpcUrl === cliqueRpc) {
    console.log(`[${networkName}] Using Clique node RPC as default: ${effectiveElRpcUrl}`);
  } else {
    console.log(`[${networkName}] Using EL RPC URL: ${effectiveElRpcUrl}`);
  }
  const result = await createBlockscoutNode({
    elRpcUrl: effectiveElRpcUrl,
    networkId,
    networkName: networkNameConfig,
    context,
  });
  
  // Update elExplorer config with RPC URL and node IP (no step update)
  const updates = {elRpcUrl: effectiveElRpcUrl};
  if (result.blockscoutIp) {
    updates.publicHost = result.blockscoutIp;
  }
  updateNetworkConfig(networkName, 'elExplorer', updates);

  const nodeData = {
    name: 'blockscout',
    ip: result.blockscoutIp,
  };
  addNodeToNetwork(networkName, 'blockscout', nodeData);
  
  console.log(`[${networkName}] Blockscout explorer created:`, result);
  return result;
}

/**
 * Execute createValidators step - create a single validator node
 */
export async function executeCreateValidator(networkName, validatorKeyJson, validatorPassword, nodeName = null, poaEnode = null, bootnodeEnr = null, beaconBootnodeEnode = null) {
  const network = getNetwork(networkName);
  if (!network) {
    throw new Error(`Network "${networkName}" not found`);
  }

  const poaStep = network.steps.initPoa;
  const bootnodeStep = network.steps.initBootnode;
  
  const effectivePoaEnode = poaEnode || (poaStep.status === 'completed' && poaStep.data ? poaStep.data.cliqueEnode : null);
  
  // Get bootnode array - first node should be beacon node (has enode for EL, enr for CL)
  const bootnodes = network.nodes?.bootnode || [];
  const firstBootnode = bootnodes.length > 0 ? bootnodes[0] : null;
  
  // Get ENR from step or first bootnode in array
  const effectiveBootnodeEnr = bootnodeEnr || 
    (bootnodeStep.status === 'completed' && bootnodeStep.data ? bootnodeStep.data.bootnodeEnr : null) ||
    (firstBootnode?.enr || null);
  
  // Get beacon enode from first bootnode in array (beacon node)
  const effectiveBeaconBootnodeEnode = beaconBootnodeEnode || (firstBootnode?.enode || null);
  
  if (!effectivePoaEnode) {
    throw new Error('POA enode is required. Provide poaEnode parameter or complete initPoa step first.');
  }
  if (!effectiveBootnodeEnr) {
    throw new Error('Bootnode ENR is required. Provide bootnodeEnr parameter or ensure bootnode is created.');
  }
  if (!effectiveBeaconBootnodeEnode) {
    throw new Error('Beacon bootnode ENODE is required. Please create beacon node first (it will be added to bootnode array).');
  }

  if (!validatorKeyJson) {
    throw new Error('Validator key JSON is required');
  }
  if (!validatorPassword) {
    throw new Error('Validator password is required');
  }

  const context = buildContextFromNetwork(network);
  const existingNodes = network.nodes?.validators || [];
  const nodeIndex = existingNodes.length + 1;
  const vmName = nodeName || `beacon-validator-node-${nodeIndex}`;

  console.log(`[${networkName}] Creating validator node: ${vmName}...`);

  // Import required modules
  const {buildEnvContent, buildVmOptions, createGcpVm, getInstanceExternalIp, REPO_URL, REPO_BRANCH} = await import('./gcpHelpers.js');
  const {DEFAULT_REMOTE_ENV} = await import('../config/defaultRemoteEnv.js');

  const BEACON_NODE_TCP_PORTS = [22, 3500, 9000, 9001, 8545, 8546, 30303];
  const BEACON_NODE_UDP_PORTS = [30303, 9000, 9001];

  function buildBeaconNodeStartupScript({validatorPassword, validatorKeyJson, envOverrides = {}}) {
    const envContent = buildEnvContent({
      ...DEFAULT_REMOTE_ENV,
      ...envOverrides,
      VALIDATOR_KEY_JSON: validatorKeyJson,
      VALIDATOR_KEY_PASSWORD: validatorPassword,
    });
    const password = validatorPassword;
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
mkdir -p data/cl/validator/validator_keys
cat > data/cl/validator/validator_keys/keystore.json <<'KEYEOF'
${validatorKeyJson}
KEYEOF
echo "${password}" > data/cl/validator/validator_keys/password.txt
chmod 600 data/cl/validator/validator_keys/password.txt

cat > .env.beacon <<'ENVEOF'
${envContent}
ENVEOF
echo "NODE_IP=$NODE_IP" >> .env.beacon
./start.sh beacon-vc .env.beacon 2>&1 | tee -a /var/log/startup-script.log

echo "=== Startup script completed ===" | tee -a /var/log/startup-script.log
date | tee -a /var/log/startup-script.log
`;
  }

  const beaconInstance = await createGcpVm({
    ...buildVmOptions(context, vmName),
    machineType: 'e2-medium',
    bootDiskSize: '30GB',
    startupScriptBuilder: (opts) =>
      buildBeaconNodeStartupScript({
        ...opts,
        validatorPassword,
        validatorKeyJson: `'${validatorKeyJson.replace(/'/g, "'\\''")}'`,
        envOverrides: {
          EL_BOOTNODES: effectiveBeaconBootnodeEnode, // Validators peer to beacon node's EL enode (from bootnode array)
          CL_BOOTNODE_ENR: effectiveBootnodeEnr, // Validators peer to bootnode ENR for CL (from bootnode array)
          ...(context?.envOverrides?.beacon || {}),
          // Apply all fork configs from network (includes CL configs and fork updates)
          ...getNodeForkConfig(network),
        },
      }),
    tcpPorts: BEACON_NODE_TCP_PORTS,
    udpPorts: BEACON_NODE_UDP_PORTS,
  });

  const beaconIp = getInstanceExternalIp(beaconInstance);
  if (beaconIp) {
    console.log(`[${networkName}] Validator node "${vmName}" External IP: ${beaconIp}`);
  }

  const nodeData = {
    name: vmName,
    ip: beaconIp || null,
  };

  addNodeToNetwork(networkName, 'validators', nodeData);
  console.log(`[${networkName}] Validator node added successfully`);
  return nodeData;
}

/**
 * Update Blockscout (e.g., change EL RPC URL and block transformer)
 */
export async function executeUpdateBlockscout(networkName, elRpcUrl, blockTransformer = null, networkId = null, networkNameDisplay = null) {
  const network = getNetwork(networkName);
  if (!network) {
    throw new Error(`Network "${networkName}" not found`);
  }

  // Get existing blockscout node
  const blockscoutNodes = network.nodes?.blockscout || [];
  if (!blockscoutNodes || blockscoutNodes.length === 0) {
    throw new Error(`No blockscout nodes found for network "${networkName}". Please create blockscout first.`);
  }

  // Use the first blockscout node (or the latest one)
  const blockscoutNode = blockscoutNodes[blockscoutNodes.length - 1];
  if (!blockscoutNode.ip) {
    throw new Error(`Blockscout node "${blockscoutNode.name}" does not have an IP address`);
  }

  const context = buildContextFromNetwork(network);
  const config = network.config || {};
  const defaultConfig = getDefaultConfig();
  const elExplorer = config.elExplorer || defaultConfig.elExplorer;
  const el = config.el || defaultConfig.el;
  
  // Support both old and new config structure
  const networkIdValue = networkId || elExplorer.networkId || el.networkId || config.networkId || 84;
  const networkNameValue = networkNameDisplay || elExplorer.networkName || el.networkName || config.networkName || `${networkName} Network`;

  if (!elRpcUrl) {
    throw new Error('EL RPC URL is required to update Blockscout');
  }

  console.log(`[${networkName}] Updating Blockscout node "${blockscoutNode.name}" at ${blockscoutNode.ip}...`);
  console.log(`[${networkName}] New EL RPC URL: ${elRpcUrl}`);
  if (blockTransformer) {
    console.log(`[${networkName}] New block transformer: ${blockTransformer}`);
  }

  // Build env updates
  const envUpdates = {
    BLOCKSCOUT_EL_RPC_URL: elRpcUrl,
    BLOCKSCOUT_TRACE_URL: elRpcUrl,
    BLOCKSCOUT_NETWORK_ID: String(networkIdValue),
    BLOCKSCOUT_NETWORK_NAME: `'${networkNameValue}'`,
  };

  // Update block transformer if provided
  if (blockTransformer) {
    envUpdates.BLOCKSCOUT_BLOCK_TRANSFORMER = blockTransformer;
  }

  // SSH in and update
  const sshConfig = buildSshConfig(blockscoutNode.ip, context);
  await updateBlockscout(sshConfig, blockscoutNode, envUpdates);

  // Update elExplorer config with new RPC URL
  const updates = {elRpcUrl};
  if (blockTransformer) {
    updates.blockTransformer = blockTransformer;
  }
  updateNetworkConfig(networkName, 'elExplorer', updates);

  console.log(`[${networkName}] Blockscout update completed successfully`);
  return {success: true, node: blockscoutNode};
}

/**
 * Execute initial network creation flow (only initPoa)
 */
export async function executeInitialFlow(networkName) {
  const steps = [];

  try {
    // Step 1: initPoa
    steps.push('initPoa');
    await executeInitPoa(networkName);

    // Update network status
    const network = getNetwork(networkName);
    network.status = 'initialized';
    saveNetwork(networkName, network);

    console.log(`\n[${networkName}] Initial flow completed successfully!`);
    console.log(`[${networkName}] Next steps: Deploy deposit contract, then create bootnode, beacon bootnode, and validators.`);
    console.log(`[${networkName}] You can also create Blockscout or Dora explorers from the menu.`);
    return {success: true, steps};
  } catch (error) {
    console.error(`[${networkName}] Error in step ${steps[steps.length - 1]}:`, error.message);
    const network = getNetwork(networkName);
    network.status = 'failed';
    saveNetwork(networkName, network);
    throw error;
  }
}

/**
 * Add a new execution node (clique/POA node)
 */
export async function addExecutionNode(networkName, nodeName = null) {
  const network = getNetwork(networkName);
  if (!network) {
    throw new Error(`Network "${networkName}" not found`);
  }

  const poaStep = network.steps.initPoa;
  if (poaStep.status !== 'completed' || !poaStep.data) {
    throw new Error('initPoa must be completed before adding execution nodes');
  }

  const context = buildContextFromNetwork(network);
  const existingNodes = network.nodes?.execution || [];
  const nodeIndex = existingNodes.length + 1;
  const vmName = nodeName || `execution-node-${nodeIndex}`;

  console.log(`[${networkName}] Creating new execution node: ${vmName}...`);

  // Import buildCliqueStartupScript from init-poa
  const {buildEnvContent, buildCommonStartupScript} = await import('./gcpHelpers.js');
  const {DEFAULT_REMOTE_ENV} = await import('../config/defaultRemoteEnv.js');

  const CLIQUE_NODE_TCP_PORTS = [22, 8545, 8546, 8551, 30303];
  const CLIQUE_NODE_UDP_PORTS = [30303];

  function buildCliqueStartupScript({sshUser, sshKey, envOverrides = {}}) {
    const envContent = buildEnvContent({
      ...DEFAULT_REMOTE_ENV,
      ...envOverrides,
      CLIQUE_MINER_ADDRESS: '0x57d68c4c9ee6dc6541ccfaf41a1125bbe17b5ce8',
      CLIQUE_MINER_PRIVATE_KEY: '91611c3437c63d19ae223c1e08fb241d3558464102686485bb747fcdf641a0fb',
      CLIQUE_MINER_PASSWORD: 'hjKYDA8Fp+Jkeutw',
      CLIQUE_MINER: true,
      EL_BOOTNODES: poaStep.data.cliqueEnode,
    });
    return buildCommonStartupScript({sshUser, sshKey, deployType: 'clique', envContent});
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

  const instance = await createGcpVm({
    ...buildVmOptions(context, vmName),
    machineType: 'e2-medium',
    bootDiskSize: '30GB',
    startupScriptBuilder: (params) =>
      buildCliqueStartupScript({
        ...params,
        envOverrides: context?.envOverrides?.clique || {},
      }),
    tcpPorts: CLIQUE_NODE_TCP_PORTS,
    udpPorts: CLIQUE_NODE_UDP_PORTS,
  });

  const nodeIp = getInstanceExternalIp(instance);
  if (!nodeIp) {
    throw new Error('Unable to determine node external IP');
  }
  console.log(`[${networkName}] Execution node External IP: ${nodeIp}`);

  const nodeEnode = await waitForCliqueEnode(nodeIp);
  console.log(`[${networkName}] Execution node ENODE: ${nodeEnode}`);

  const nodeData = {
    name: vmName,
    ip: nodeIp,
    enode: nodeEnode,
  };

  addNodeToNetwork(networkName, 'execution', nodeData);
  console.log(`[${networkName}] Execution node added successfully`);
  return nodeData;
}

/**
 * Add a new beacon node
 */
export async function addBeaconNode(networkName, nodeName = null, archiveMode = false) {
  const network = getNetwork(networkName);
  if (!network) {
    throw new Error(`Network "${networkName}" not found`);
  }

  const poaStep = network.steps.initPoa;
  const bootnodeStep = network.steps.initBootnode;
  if (poaStep.status !== 'completed' || !poaStep.data) {
    throw new Error('initPoa must be completed before adding beacon nodes');
  }
  if (bootnodeStep.status !== 'completed' || !bootnodeStep.data) {
    throw new Error('initBootnode must be completed before adding beacon nodes');
  }

  const context = buildContextFromNetwork(network);
  // Count beacon nodes (not bootnodes)
  const existingBeaconNodes = network.nodes?.beacon || [];
  const nodeIndex = existingBeaconNodes.length + 1;
  const vmName = nodeName || `beacon-node-${nodeIndex}`;

  console.log(`[${networkName}] Creating new beacon node: ${vmName}...`);

  // Import required modules
  const {buildEnvContent, REPO_URL, REPO_BRANCH} = await import('./gcpHelpers.js');
  const {DEFAULT_REMOTE_ENV} = await import('../config/defaultRemoteEnv.js');

  const BEACON_TCP_PORTS = [22, 3500, 9000, 9001, 8545, 8546, 30303];
  const BEACON_UDP_PORTS = [30303, 9000, 9001];

  // Get bootnode info from bootnode array
  const bootnodesForBeacon = network.nodes?.bootnode || [];
  const firstBootnodeForBeacon = bootnodesForBeacon.length > 0 ? bootnodesForBeacon[0] : null;
  const effectivePoaEnode = poaEnode || (poaStep.status === 'completed' && poaStep.data ? poaStep.data.cliqueEnode : null);
  const effectiveBootnodeEnr = bootnodeEnr || 
    (bootnodeStep.status === 'completed' && bootnodeStep.data ? bootnodeStep.data.bootnodeEnr : null) ||
    (firstBootnodeForBeacon?.enr || null);

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

  const beaconInstance = await createGcpVm({
    ...buildVmOptions(context, vmName),
    machineType: 'e2-medium',
    bootDiskSize: '30GB',
    startupScriptBuilder: (params) =>
      buildBeaconStartupScript({
        ...params,
        poaEnode: poaStep.data.cliqueEnode,
        bootnodeEnr: bootnodeStep.data.bootnodeEnr,
        envOverrides: {
          EL_BOOTNODES: poaStep.data.cliqueEnode,
          CL_BOOTNODE_ENR: bootnodeStep.data.bootnodeEnr,
          EL_BOOT_NODE_KEY: '31640af736ec4dfef9d776189b3ca4e6d7732d853b815ece7408c9d3c4e10433',
          ...(context?.envOverrides?.beacon || {}),
          // Apply all fork configs from network (includes CL configs and fork updates)
          ...getNodeForkConfig(network),
          // Add archive mode if requested
          ...(archiveMode ? {CL_ARCHIVE_MODE: 'true'} : {}),
        },
      }),
    tcpPorts: BEACON_TCP_PORTS,
    udpPorts: BEACON_UDP_PORTS,
  });

  const beaconIp = getInstanceExternalIp(beaconInstance);
  if (!beaconIp) {
    throw new Error('Unable to determine beacon external IP');
  }
  console.log(`[${networkName}] Beacon External IP: ${beaconIp}`);

  const beaconEnode = await waitForCliqueEnode(beaconIp, {timeoutMs: 300000, pollIntervalMs: 2000});
  console.log(`[${networkName}] Beacon ENODE: ${beaconEnode}`);

  const nodeData = {
    name: vmName,
    ip: beaconIp,
    enode: beaconEnode,
  };

  // Add to beacon array (not bootnode array)
  addNodeToNetwork(networkName, 'beacon', nodeData);
  console.log(`[${networkName}] Beacon node added successfully`);
  return nodeData;
}

/**
 * Update fork configuration for beacon and validator nodes only (excludes clique and bootnode)
 * @param {string} networkName - Network name
 * @param {object} envUpdates - Environment variables to update
 * @param {number} delayMs - Delay in milliseconds between updates (default: 5000ms for validators, 3000ms for beacon)
 */
export async function updateForkForAllNodes(networkName, envUpdates, delayMs = null) {
  const network = getNetwork(networkName);
  if (!network) {
    throw new Error(`Network "${networkName}" not found`);
  }

  // Save fork config to network for future node creation
  if (!network.config.forkConfig) {
    network.config.forkConfig = {};
  }
  network.config.forkConfig = {...network.config.forkConfig, ...envUpdates};
  saveNetwork(networkName, network);

  const context = buildContextFromNetwork(network);
  console.log(`[${networkName}] Updating fork configuration for beacon and validator nodes...`);
  console.log('Environment updates:', envUpdates);

  const errors = [];
  const defaultBeaconDelay = delayMs || 3000; // 3 seconds between beacon nodes
  const defaultValidatorDelay = delayMs || 5000; // 5 seconds between validator nodes

  // Helper function to wait
  const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  // Update beacon node in bootnode array (first node with enode)
  const bootnodes = network.nodes?.bootnode || [];
  const beaconBootnode = bootnodes.find(b => b.enode);
  if (beaconBootnode && beaconBootnode.ip) {
    try {
      const sshConfig = buildSshConfig(beaconBootnode.ip, context);
      await updateBeacon(sshConfig, beaconBootnode, envUpdates);
      console.log(`[${networkName}] ✓ Updated beacon bootnode: ${beaconBootnode.name}`);
    } catch (error) {
      console.error(`[${networkName}] ✗ Failed to update beacon bootnode ${beaconBootnode.name}:`, error.message);
      errors.push({node: beaconBootnode.name, error: error.message});
    }
  }

  // Update additional beacon nodes (not bootnodes)
  const beaconNodes = network.nodes?.beacon || [];
  if (beaconNodes.length > 0) {
    for (let i = 0; i < beaconNodes.length; i++) {
      const node = beaconNodes[i];
      if (!node.ip) continue;
      try {
        const sshConfig = buildSshConfig(node.ip, context);
        await updateBeacon(sshConfig, node, envUpdates);
        console.log(`[${networkName}] ✓ Updated beacon node: ${node.name}`);
        // Add delay before next beacon node (except for the last one)
        if (i < beaconNodes.length - 1) {
          console.log(`[${networkName}] Waiting ${defaultBeaconDelay / 1000}s before next update...`);
          await wait(defaultBeaconDelay);
        }
      } catch (error) {
        console.error(`[${networkName}] ✗ Failed to update beacon node ${node.name}:`, error.message);
        errors.push({node: node.name, error: error.message});
      }
    }
  }

  // Update validator nodes sequentially with delay
  if (network.nodes?.validators && network.nodes.validators.length > 0) {
    console.log(`[${networkName}] Updating ${network.nodes.validators.length} validator node(s) sequentially...`);
    for (let i = 0; i < network.nodes.validators.length; i++) {
      const node = network.nodes.validators[i];
      if (!node.ip) continue;
      try {
        const sshConfig = buildSshConfig(node.ip, context);
        await updateBeaconVc(sshConfig, node, envUpdates);
        console.log(`[${networkName}] ✓ Updated validator node: ${node.name} (${i + 1}/${network.nodes.validators.length})`);
        // Add delay before next validator node (except for the last one)
        if (i < network.nodes.validators.length - 1) {
          console.log(`[${networkName}] Waiting ${defaultValidatorDelay / 1000}s before next validator update...`);
          await wait(defaultValidatorDelay);
        }
      } catch (error) {
        console.error(`[${networkName}] ✗ Failed to update validator node ${node.name}:`, error.message);
        errors.push({node: node.name, error: error.message});
      }
    }
  }

  if (errors.length > 0) {
    console.log(`\n[${networkName}] Completed with ${errors.length} error(s):`);
    errors.forEach(({node, error}) => {
      console.log(`  - ${node}: ${error}`);
    });
  } else {
    console.log(`\n[${networkName}] ✓ All beacon and validator nodes updated successfully`);
  }

  return {success: errors.length === 0, errors};
}
