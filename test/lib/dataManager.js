#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import {fileURLToPath} from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DATA_DIR = path.join(__dirname, '..', 'data');
const NETWORKS_FILE = path.join(DATA_DIR, 'networks.json');
const CURRENT_NETWORK_FILE = path.join(DATA_DIR, 'current-network.json');

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, {recursive: true});
}

/**
 * Load all networks from storage
 */
export function loadNetworks() {
  if (!fs.existsSync(NETWORKS_FILE)) {
    return {};
  }
  try {
    const content = fs.readFileSync(NETWORKS_FILE, 'utf8');
    return JSON.parse(content);
  } catch (error) {
    console.error('[dataManager] Error loading networks:', error.message);
    return {};
  }
}

/**
 * Save networks to storage
 */
export function saveNetworks(networks) {
  fs.writeFileSync(NETWORKS_FILE, JSON.stringify(networks, null, 2));
}

/**
 * Get a specific network by name
 */
export function getNetwork(networkName) {
  const networks = loadNetworks();
  return networks[networkName] || null;
}

/**
 * Save or update a network
 */
export function saveNetwork(networkName, networkData) {
  const networks = loadNetworks();
  networks[networkName] = {
    ...networkData,
    updatedAt: new Date().toISOString(),
  };
  saveNetworks(networks);
  return networks[networkName];
}

/**
 * Delete a network
 */
export function deleteNetwork(networkName) {
  const networks = loadNetworks();
  delete networks[networkName];
  saveNetworks(networks);
}

/**
 * List all network names
 */
export function listNetworkNames() {
  const networks = loadNetworks();
  return Object.keys(networks);
}

/**
 * Get current active network
 */
export function getCurrentNetwork() {
  if (!fs.existsSync(CURRENT_NETWORK_FILE)) {
    return null;
  }
  try {
    const content = fs.readFileSync(CURRENT_NETWORK_FILE, 'utf8');
    const data = JSON.parse(content);
    return data.networkName || null;
  } catch (error) {
    return null;
  }
}

/**
 * Set current active network
 */
export function setCurrentNetwork(networkName) {
  const networks = loadNetworks();
  if (!networks[networkName]) {
    throw new Error(`Network "${networkName}" does not exist`);
  }
  fs.writeFileSync(
    CURRENT_NETWORK_FILE,
    JSON.stringify({networkName, switchedAt: new Date().toISOString()}, null, 2),
  );
}

/**
 * Get current network data
 */
export function getCurrentNetworkData() {
  const currentName = getCurrentNetwork();
  if (!currentName) {
    return null;
  }
  return getNetwork(currentName);
}

export function clearCurrentNetwork() {
  if (fs.existsSync(CURRENT_NETWORK_FILE)) {
    fs.unlinkSync(CURRENT_NETWORK_FILE);
  }
}

/**
 * Get default config structure
 */
export function getDefaultConfig() {
  return {
    server: {
      projectId: '',
      zone: 'asia-northeast1-a',
      sshUser: 'linux',
      sshPrivateKeyPath: null,
    },
    el: {
      chainId: 84,
      networkId: 84,
      networkName: '',
      genesisFile: 'genesis.json',
      wsPort: 8546,
      rpcPort: 8545,
      // Fork configs
      terminalTotalDifficulty: null,
      shanghaiTime: null,
      cancunTime: null,
      pragueTime: null,
      gethImage: 'ethereum/client-go:v1.11.6',
    },
    cl: {
      depositContractAddress: '0x4242424242424242424242424242424242424242',
      minGenesisActiveValidatorCount: 8,
      depositBlock: 0,
      genesisStateUrl: null,
      // Fork configs
      terminalTotalDifficulty: null,
      capellaForkEpoch: null,
      denebForkEpoch: null,
      electraForkEpoch: null,
      lighthouseImage: 'sigp/lighthouse:v7.0.1',
    },
    elExplorer: {
      enabled: true,
      elRpcUrl: null, // Will be set from clique node
      networkId: 84,
      networkName: '',
      publicHost: null, // Will be set to node IP
      publicProtocol: 'http',
      proxyPort: 80,
    },
    clExplorer: {
      enabled: true,
      clRpcUrl: null, // Will be set from beacon node
      elRpcUrl: null, // Will be set from beacon node
    },
    forkConfig: {}, // Additional fork configs applied via updateFork
  };
}

/**
 * Initialize a new network structure
 */
export function initNetwork(networkName, config = {}) {
  const defaultConfig = getDefaultConfig();
  
  // Merge provided config with defaults; keep CL empty unless provided
  const mergedConfig = {
    server: {...defaultConfig.server, ...(config.server || {})},
    el: {...defaultConfig.el, ...(config.el || {})},
    cl: config.cl ? {...defaultConfig.cl, ...config.cl} : {},
    elExplorer: {...defaultConfig.elExplorer, ...(config.elExplorer || {})},
    clExplorer: {...defaultConfig.clExplorer, ...(config.clExplorer || {})},
    forkConfig: config.forkConfig || {},
  };
  
  // Backward compatibility: if old config format is provided, migrate it
  if (config.projectId || config.zone || config.sshUser) {
    mergedConfig.server = {
      ...mergedConfig.server,
      projectId: config.projectId || mergedConfig.server.projectId,
      zone: config.zone || mergedConfig.server.zone,
      sshUser: config.sshUser || mergedConfig.server.sshUser,
    };
  }
  if (config.networkId || config.networkName) {
    mergedConfig.el = {
      ...mergedConfig.el,
      networkId: config.networkId || mergedConfig.el.networkId,
      networkName: config.networkName || mergedConfig.el.networkName,
    };
    mergedConfig.elExplorer = {
      ...mergedConfig.elExplorer,
      networkId: config.networkId || mergedConfig.elExplorer.networkId,
      networkName: config.networkName || mergedConfig.elExplorer.networkName,
    };
  }
  if (config.clDepositContractAddress || config.clMinGenesisActiveValidatorCount !== undefined || config.clDepositBlock !== undefined) {
    mergedConfig.cl = {
      ...mergedConfig.cl,
      depositContractAddress: config.clDepositContractAddress || mergedConfig.cl.depositContractAddress,
      minGenesisActiveValidatorCount: config.clMinGenesisActiveValidatorCount !== undefined ? config.clMinGenesisActiveValidatorCount : mergedConfig.cl.minGenesisActiveValidatorCount,
      depositBlock: config.clDepositBlock !== undefined ? config.clDepositBlock : mergedConfig.cl.depositBlock,
      genesisStateUrl: config.clGenesisStateUrl || mergedConfig.cl.genesisStateUrl,
    };
  }
  
  const network = {
    name: networkName,
    createdAt: new Date().toISOString(),
    status: 'initializing',
    config: mergedConfig,
    steps: {
      initPoa: {status: 'pending', data: null},
      initBootnode: {status: 'pending', data: null},
    },
    nodes: {
      clique: [],
      bootnode: [],
      beacon: [], // Additional beacon nodes (not bootnodes)
      validators: [],
      execution: [], // Additional execution nodes
      blockscout: [], // Blockscout nodes
      dora: [], // Dora explorer nodes
    },
    env: {},
  };
  saveNetwork(networkName, network);
  return network;
}

/**
 * Update network config section
 */
export function updateNetworkConfig(networkName, section, configUpdates) {
  const network = getNetwork(networkName);
  if (!network) {
    throw new Error(`Network "${networkName}" does not exist`);
  }
  
  if (!network.config) {
    network.config = getDefaultConfig();
  }
  
  if (!network.config[section]) {
    const defaults = getDefaultConfig();
    network.config[section] = defaults[section] || {};
  }
  
  network.config[section] = {
    ...network.config[section],
    ...configUpdates,
  };
  
  saveNetwork(networkName, network);
  return network.config[section];
}

/**
 * Get network config section
 */
export function getNetworkConfigSection(networkName, section) {
  const network = getNetwork(networkName);
  if (!network) {
    throw new Error(`Network "${networkName}" does not exist`);
  }
  
  if (!network.config) {
    network.config = getDefaultConfig();
  }
  
  if (!network.config[section]) {
    const defaults = getDefaultConfig();
    network.config[section] = defaults[section] || {};
  }
  
  return network.config[section];
}

/**
 * Update a step in the network
 */
export function updateNetworkStep(networkName, stepName, stepData) {
  const network = getNetwork(networkName);
  if (!network) {
    throw new Error(`Network "${networkName}" does not exist`);
  }
  network.steps[stepName] = {
    status: 'completed',
    data: stepData,
    completedAt: new Date().toISOString(),
  };
  
  // Also update nodes list based on step
  if (!network.nodes) {
    network.nodes = {
      clique: [],
      bootnode: [],
      beacon: [],
      validators: [],
      execution: [],
      blockscout: [],
      dora: [],
    };
  }
  
  if (stepName === 'initPoa' && stepData.cliqueIp) {
    network.nodes.clique = [{name: 'clique', ip: stepData.cliqueIp, enode: stepData.cliqueEnode}];
  } else if (stepName === 'initBootnode' && stepData.bootnodeIp) {
    // First bootnode entry (Lighthouse bootnode only, no EL)
    network.nodes.bootnode = [{name: 'bootnode', ip: stepData.bootnodeIp, enr: stepData.bootnodeEnr}];
  } else if (stepName === 'initBeacon' && stepData.beaconIp) {
    // Backward compatibility: old initBeacon step - add to bootnode array
    if (!network.nodes.bootnode) {
      network.nodes.bootnode = [];
    }
    // Check if beacon node already exists in bootnode array
    const existingBeacon = network.nodes.bootnode.find(b => b.enode === stepData.beaconEnode);
    if (!existingBeacon) {
      network.nodes.bootnode.push({name: 'beacon-bootnode', ip: stepData.beaconIp, enode: stepData.beaconEnode, enr: stepData.bootnodeEnr});
    }
  } else if (stepName === 'createValidators' && stepData.nodes) {
    network.nodes.validators = stepData.nodes;
  }
  
  saveNetwork(networkName, network);
  return network;
}

/**
 * Add a node to the network
 */
export function addNodeToNetwork(networkName, nodeType, nodeData) {
  const network = getNetwork(networkName);
  if (!network) {
    throw new Error(`Network "${networkName}" does not exist`);
  }
  if (!network.nodes) {
    network.nodes = {
      clique: [],
      bootnode: [],
      beacon: [],
      validators: [],
      execution: [],
      blockscout: [],
      dora: [],
    };
  }
  if (!network.nodes[nodeType]) {
    network.nodes[nodeType] = [];
  }
  network.nodes[nodeType].push({
    ...nodeData,
    addedAt: new Date().toISOString(),
  });
  saveNetwork(networkName, network);
  return network;
}

/**
 * Get network status summary
 */
export function getNetworkStatus(networkName) {
  const network = getNetwork(networkName);
  if (!network) {
    return null;
  }
  const steps = network.steps;
  const completed = Object.values(steps).filter((s) => s.status === 'completed').length;
  const total = Object.keys(steps).length;
  return {
    name: network.name,
    status: network.status,
    progress: `${completed}/${total}`,
    steps,
    createdAt: network.createdAt,
    updatedAt: network.updatedAt,
  };
}
