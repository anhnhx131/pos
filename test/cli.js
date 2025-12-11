#!/usr/bin/env node
// Core data management
import {
  loadNetworks,
  getNetwork,
  saveNetwork,
  deleteNetwork,
  listNetworkNames,
  getCurrentNetwork,
  setCurrentNetwork,
  clearCurrentNetwork,
  getCurrentNetworkData,
  initNetwork,
  getNetworkStatus,
  updateNetworkConfig,
  getNetworkConfigSection,
  getDefaultConfig,
} from './lib/dataManager.js';

// Network operations
import {
  executeInitPoa,
  executeInitBootnode,
  executeInitBeacon,
  executeCreateDora,
  executeCreateBlockscout,
  executeCreateValidator,
  executeInitialFlow,
  addExecutionNode,
  addBeaconNode,
  executeUpdateBlockscout,
  updateForkForAllNodes,
} from './lib/networkManager.js';

// CLI utilities
import {
  prompt,
  confirm,
  select,
  displayTable,
  displayKeyValue,
  waitForEnter,
  separator,
  sectionHeader,
} from './lib/prompts.js';

// GCP helpers
import {loadDeploymentContext} from './lib/gcpHelpers.js';

/**
 * Main menu
 */
async function showMainMenu() {
  separator();
  console.log('  POS Test Network Manager');
  separator();
  const currentNetwork = getCurrentNetwork();
  if (currentNetwork) {
    console.log(`Current Network: ${currentNetwork}`);
  } else {
    console.log('Current Network: None');
  }
  console.log();

  const options = [
    'Create new network',
    'List networks',
    'Switch network',
    'View network details',
    'Manage network config',
    'Prepare CL config',
    'Add bootnode',
    'Add beacon node',
    'Add validator node',
    'Create blockscout',
    'Create dora',
    'Update CL config',
    'Update blockscout RPC',
    'Update fork (beacon & validator)',
    'Delete network',
    'Exit',
  ];

  return await select('Main Menu', options);
}

/**
 * Create a new network
 */
async function createNewNetwork() {
  sectionHeader('Create New Network');

  const name = await prompt('Network name: ');
  if (!name) {
    console.log('Network name is required');
    return;
  }

  const networks = loadNetworks();
  if (networks[name]) {
    console.log(`Network "${name}" already exists`);
    return;
  }

  // Load default context for initial values
  let defaultContext;
  try {
    defaultContext = loadDeploymentContext();
  } catch (error) {
    console.log('Warning: Could not load default context, using defaults');
    defaultContext = {
      projectId: '',
      zone: 'asia-northeast1-a',
      sshUser: 'linux',
    };
  }

  console.log('\nServer Configuration:');
  const projectId = await prompt(`Project ID [${defaultContext.projectId}]: `) || defaultContext.projectId;
  const zone = await prompt(`Zone [${defaultContext.zone}]: `) || defaultContext.zone;
  const sshUser = await prompt(`SSH User [${defaultContext.sshUser}]: `) || defaultContext.sshUser;

  console.log('\nEL (Execution Layer) Configuration:');
  const elChainId = await prompt('EL Chain ID [84]: ') || '84';
  const elNetworkId = await prompt('EL Network ID [84]: ') || '84';
  const elGethImage = await prompt('Geth Docker Image [ethereum/client-go:v1.11.6]: ') || 'ethereum/client-go:v1.11.6';

  // Use network name for all networkName fields
  const networkName = `${name} Network`;

  const config = {
    server: {
      projectId,
      zone,
      sshUser,
    },
    el: {
      chainId: parseInt(elChainId, 10),
      networkId: parseInt(elNetworkId, 10),
      networkName: networkName,
      gethImage: elGethImage,
    },
    elExplorer: {
      enabled: true,
      networkId: parseInt(elNetworkId, 10),
      networkName: networkName,
      elRpcUrl: null,
    },
    clExplorer: {
      enabled: true,
    },
    forkConfig: {},
  };

  console.log('\nReview Configuration:');
  console.log('\n=== Server ===');
  displayKeyValue(config.server);
  console.log('\n=== EL (Execution Layer) ===');
  displayKeyValue(config.el);
  console.log('\nNote: CL config will be asked when creating bootnode/beacon/validator nodes');

  const confirmed = await confirm('\nCreate network with these settings?');
  if (!confirmed) {
    console.log('Cancelled');
    return;
  }

  const network = initNetwork(name, config);
  console.log(`\nNetwork "${name}" created successfully!`);

  // Ask if user wants to set as current
  const setCurrent = await confirm('Set as current network?');
  if (setCurrent) {
    setCurrentNetwork(name);
    console.log(`Network "${name}" is now current`);
  }

  // Immediately create initial clique node
  console.log('\nCreating initial clique node (initPoa)...');
  try {
    await executeInitPoa(name);
    console.log('Initial clique node created successfully.');
  } catch (error) {
    console.error('Failed to create initial clique node:', error.message);
    // Rollback network if init fails
    deleteNetwork(name);
    if (setCurrent) {
      clearCurrentNetwork();
    }
    return;
  }
  await waitForEnter();
}

/**
 * List all networks
 */
async function listNetworks() {
  sectionHeader('Networks List');

  const networks = loadNetworks();
  const networkNames = Object.keys(networks);
  const currentNetwork = getCurrentNetwork();

  if (networkNames.length === 0) {
    console.log('No networks found');
    await waitForEnter();
    return;
  }

  const headers = ['Name', 'Status', 'Progress', 'Created'];
  const rows = networkNames.map((name) => {
    const status = getNetworkStatus(name);
    const marker = name === currentNetwork ? '*' : ' ';
    return [
      `${marker}${name}`,
      status.status,
      status.progress,
      new Date(status.createdAt).toLocaleDateString(),
    ];
  });

  displayTable(headers, rows);
  console.log('\n* = current network');
  await waitForEnter();
}

/**
 * Switch current network
 */
async function switchNetwork() {
  sectionHeader('Switch Network');

  const networkNames = listNetworkNames();
  if (networkNames.length === 0) {
    console.log('No networks available');
    await waitForEnter();
    return;
  }

  const currentNetwork = getCurrentNetwork();
  const options = networkNames.map((name) => ({
    label: name === currentNetwork ? `${name} (current)` : name,
    value: name,
  }));

  const selected = await select('Select network to switch to', options);
  setCurrentNetwork(selected);
  console.log(`\nSwitched to network: ${selected}`);
  await waitForEnter();
}

/**
 * View network details
 */
async function viewNetworkDetails() {
  sectionHeader('Network Details');

  const networkNames = listNetworkNames();
  if (networkNames.length === 0) {
    console.log('No networks available');
    await waitForEnter();
    return;
  }

  const selected = await select('Select network to view', networkNames);
  const status = getNetworkStatus(selected);
  const network = getNetwork(selected);

  console.log('\nNetwork Information:');
  displayKeyValue({
    Name: status.name,
    Status: status.status,
    Progress: status.progress,
    Created: new Date(status.createdAt).toLocaleString(),
    Updated: new Date(status.updatedAt).toLocaleString(),
  });

  console.log('\nConfiguration:');
  const config = network.config || {};
  
  // Support both old and new config structure
  if (config.server || config.el || config.cl) {
    // New structure
    console.log('\n=== Server Configuration ===');
    displayKeyValue(config.server || {});
    console.log('\n=== EL (Execution Layer) Configuration ===');
    displayKeyValue(config.el || {});
    console.log('\n=== CL (Consensus Layer) Configuration ===');
    displayKeyValue(config.cl || {});
    console.log('\n=== EL Explorer (Blockscout) Configuration ===');
    displayKeyValue(config.elExplorer || {});
    console.log('\n=== CL Explorer (Dora) Configuration ===');
    displayKeyValue(config.clExplorer || {});
    if (config.forkConfig && Object.keys(config.forkConfig).length > 0) {
      console.log('\n=== Additional Fork Configuration ===');
      displayKeyValue(config.forkConfig);
    }
  } else {
    // Old structure (backward compatibility)
    displayKeyValue(config);
  }

  console.log('\nSteps Status:');
  Object.entries(status.steps).forEach(([stepName, step]) => {
    const statusIcon = step.status === 'completed' ? '✓' : step.status === 'pending' ? '○' : '✗';
    console.log(`  ${statusIcon} ${stepName}: ${step.status}`);
    if (step.data && typeof step.data === 'object') {
      Object.entries(step.data).forEach(([key, value]) => {
        if (typeof value === 'string' && value.length < 100) {
          console.log(`      ${key}: ${value}`);
        }
      });
    }
  });

  await waitForEnter();
}

/**
 * Manage network steps
 */
async function manageNetworkSteps() {
  sectionHeader('Manage Network Steps');

  const networkNames = listNetworkNames();
  if (networkNames.length === 0) {
    console.log('No networks available');
    await waitForEnter();
    return;
  }

  const selected = await select('Select network', networkNames);
  const network = getNetwork(selected);

  const stepOptions = [
    {label: 'Init POA', value: 'initPoa', func: executeInitPoa},
    {label: 'Create Blockscout', value: 'createBlockscout', func: executeCreateBlockscout},
    {label: 'Update Blockscout RPC', value: 'updateBlockscout', func: null},
    {label: 'Init Bootnode', value: 'initBootnode', func: executeInitBootnode},
    {label: 'Init Beacon', value: 'initBeacon', func: executeInitBeacon},
    {label: 'Create Dora', value: 'createDora', func: executeCreateDora},
    {label: 'Initial Flow (POA + Blockscout)', value: 'initialFlow', func: null},
    {label: 'Back to main menu', value: 'back', func: null},
  ];

  while (true) {
    console.log(`\nNetwork: ${selected}`);
    const stepStatus = getNetworkStatus(selected);
    console.log(`Progress: ${stepStatus.progress}`);

    const action = await select('Select action', stepOptions);
    if (action === 'back') {
      break;
    }

    if (action === 'initialFlow') {
      console.log('\nInitial Flow will create:');
      console.log('  1. POA/Clique node');
      console.log('  2. Blockscout explorer');
      console.log('\nAfter this, you can deploy deposit contract, then create bootnode, beacon, dora, and validators.');

      const confirmed = await confirm('\nProceed with initial flow?');
      if (confirmed) {
        try {
          await executeInitialFlow(selected);
          console.log('\nInitial flow completed successfully!');
        } catch (error) {
          console.error('\nError:', error.message);
        }
      }
      await waitForEnter();
      continue;
    }

    if (action === 'updateBlockscout') {
      const poaStep = network.steps.initPoa;
      const cliqueRpc = poaStep.status === 'completed' && poaStep.data ? `http://${poaStep.data.cliqueIp}:8545` : '';
      
      // Get existing RPC from config (support both old and new structure)
      const config = network.config || {};
      const elExplorer = config.elExplorer || {};
      const existingRpc = elExplorer.elRpcUrl || config.elRpcUrl || cliqueRpc;
      
      const currentBlockscout = (network.nodes?.blockscout || [])[0];

      console.log('\nUpdate Blockscout RPC:');
      if (currentBlockscout?.ip) {
        console.log(`Current Blockscout IP: ${currentBlockscout.ip}`);
      }
      if (cliqueRpc && existingRpc === cliqueRpc) {
        console.log(`Current RPC: ${existingRpc} (from Clique node)`);
      } else if (existingRpc) {
        console.log(`Current RPC: ${existingRpc}`);
      }
      
      const rpcInput = await prompt(`New EL RPC URL [${existingRpc || cliqueRpc || 'required'}]: `);
      const newRpc = rpcInput || existingRpc || cliqueRpc;
      if (!newRpc) {
        console.log('EL RPC URL is required');
        await waitForEnter();
        continue;
      }

      // Support both old and new config structure for networkId and networkName
      const el = config.el || {};
      const networkIdDefault = elExplorer.networkId || el.networkId || config.networkId || 84;
      const networkNameDefault = elExplorer.networkName || el.networkName || config.networkName || `${selected} Network`;

      const networkIdInput = await prompt(`Network ID [${networkIdDefault}]: `);
      const networkNameInput = await prompt(`Network Name [${networkNameDefault}]: `);

      const confirmed = await confirm('\nProceed with updating Blockscout?');
      if (!confirmed) {
        continue;
      }

      try {
        await executeUpdateBlockscout(
          selected,
          newRpc,
          networkIdInput ? Number(networkIdInput) : networkIdDefault,
          networkNameInput || networkNameDefault,
        );
        console.log('\nBlockscout RPC updated successfully!');
      } catch (error) {
        console.error('\nError:', error.message);
      }
      await waitForEnter();
      continue;
    }

    // Handle steps that may need additional parameters
    if (action === 'initBootnode' || action === 'initBeacon' || action === 'createDora') {
      const poaStep = network.steps.initPoa;
      const bootnodeStep = network.steps.initBootnode;
      
      let poaEnode = null;
      let bootnodeEnr = null;
      let clRpcUrl = null;
      let elRpcUrl = null;

      if (action === 'initBootnode' || action === 'initBeacon') {
        if (poaStep.status !== 'completed' || !poaStep.data) {
          console.log('\nPOA enode is required. Please provide:');
          poaEnode = await prompt('POA ENODE: ');
          if (!poaEnode) {
            console.log('POA ENODE is required');
            await waitForEnter();
            continue;
          }
        }
      }

      if (action === 'initBeacon') {
        if (bootnodeStep.status !== 'completed' || !bootnodeStep.data) {
          console.log('\nBootnode ENR is required. Please provide:');
          bootnodeEnr = await prompt('Bootnode ENR: ');
          if (!bootnodeEnr) {
            console.log('Bootnode ENR is required');
            await waitForEnter();
            continue;
          }
        }
      }

      if (action === 'createDora') {
        const beaconStep = network.steps.initBeacon;
        if (beaconStep.status !== 'completed' || !beaconStep.data) {
          console.log('\nBeacon node RPC URLs are required. Please provide:');
          clRpcUrl = await prompt('CL RPC URL (e.g., http://IP:3500): ');
          elRpcUrl = await prompt('EL RPC URL (e.g., http://IP:8545): ');
          if (!clRpcUrl || !elRpcUrl) {
            console.log('Both CL and EL RPC URLs are required');
            await waitForEnter();
            continue;
          }
        }
      }
    }

    const stepOption = stepOptions.find((opt) => opt.value === action);
    if (!stepOption || !stepOption.func) {
      continue;
    }

    // Check prerequisites
    const step = network.steps[action];
    if (step.status === 'completed') {
      const overwrite = await confirm(`Step "${action}" is already completed. Re-run?`);
      if (!overwrite) {
        continue;
      }
    }

    // Show step info and env
    console.log(`\nExecuting step: ${action}`);
    console.log(`Network: ${selected}`);
    if (network.config) {
      console.log('\nConfiguration:');
      displayKeyValue(network.config);
    }

    const confirmed = await confirm('\nProceed with this step?');
    if (!confirmed) {
      continue;
    }

    try {
      if (action === 'initBootnode') {
        const poaStep = network.steps.initPoa;
        const poaEnode = poaStep.status === 'completed' && poaStep.data ? poaStep.data.cliqueEnode : null;
        await executeInitBootnode(selected, poaEnode);
      } else if (action === 'initBeacon') {
        const poaStep = network.steps.initPoa;
        const bootnodeStep = network.steps.initBootnode;
        const poaEnode = poaStep.status === 'completed' && poaStep.data ? poaStep.data.cliqueEnode : null;
        const bootnodeEnr = bootnodeStep.status === 'completed' && bootnodeStep.data ? bootnodeStep.data.bootnodeEnr : null;
        await executeInitBeacon(selected, poaEnode, bootnodeEnr);
      } else if (action === 'createDora') {
        const beaconStep = network.steps.initBeacon;
        const clRpcUrl = beaconStep.status === 'completed' && beaconStep.data ? `http://${beaconStep.data.beaconIp}:3500` : null;
        const elRpcUrl = beaconStep.status === 'completed' && beaconStep.data ? `http://${beaconStep.data.beaconIp}:8545` : null;
        await executeCreateDora(selected, clRpcUrl, elRpcUrl);
      } else {
        await stepOption.func(selected);
      }
      console.log(`\nStep "${action}" completed successfully!`);
    } catch (error) {
      console.error(`\nError executing step "${action}":`, error.message);
    }
    await waitForEnter();
  }
}

/**
 * Add execution node menu
 */
async function addExecutionNodeMenu() {
  sectionHeader('Add Execution Node');

  const networkNames = listNetworkNames();
  if (networkNames.length === 0) {
    console.log('No networks available');
    await waitForEnter();
    return;
  }

  const selected = await select('Select network', networkNames);
  const network = getNetwork(selected);

  const poaStep = network.steps.initPoa;
  if (poaStep.status !== 'completed') {
    console.log('initPoa must be completed before adding execution nodes');
    await waitForEnter();
    return;
  }

  const nodeName = await prompt('Node name (leave empty for auto-generated): ') || null;

  console.log(`\nAdding execution node to network: ${selected}`);
  if (nodeName) {
    console.log(`Node name: ${nodeName}`);
  }

  const confirmed = await confirm('Proceed?');
  if (!confirmed) {
    return;
  }

  try {
    const result = await addExecutionNode(selected, nodeName);
    console.log(`\nExecution node added successfully!`);
    console.log(`  Name: ${result.name}`);
    console.log(`  IP: ${result.ip}`);
    console.log(`  ENODE: ${result.enode}`);
  } catch (error) {
    console.error(`\nError:`, error.message);
  }
  await waitForEnter();
}

/**
 * Add bootnode menu
 */
async function addBootnodeMenu() {
  sectionHeader('Add Bootnode');

  const networkNames = listNetworkNames();
  if (networkNames.length === 0) {
    console.log('No networks available');
    await waitForEnter();
    return;
  }

  const selected = await select('Select network', networkNames);
  const network = getNetwork(selected);

  const poaStep = network.steps.initPoa;
  if (poaStep.status !== 'completed' || !poaStep.data) {
    console.log('initPoa must be completed before adding bootnode');
    await waitForEnter();
    return;
  }

  if (!(await requireClConfig(network))) {
    return;
  }

  const poaEnode = poaStep.data.cliqueEnode;
  const nodeName = await prompt('Node name (leave empty for auto-generated): ') || null;

  console.log(`\nAdding bootnode to network: ${selected}`);
  if (nodeName) {
    console.log(`Node name: ${nodeName}`);
  }

  const confirmed = await confirm('Proceed?');
  if (!confirmed) {
    return;
  }

  try {
    const result = await executeInitBootnode(selected, poaEnode, nodeName || undefined);
    console.log(`\nBootnode added successfully!`);
    console.log(`  Name: ${result.name || nodeName || 'bootnode'}`);
    console.log(`  ENR: ${result.bootnodeEnr || 'N/A'}`);
    console.log(`  IP: ${result.bootnodeIp || 'N/A'}`);
  } catch (error) {
    console.error(`\nError:`, error.message);
  }
  await waitForEnter();
}

/**
 * Add beacon node menu
 */
async function addBeaconNodeMenu() {
  sectionHeader('Add Beacon Node');

  const networkNames = listNetworkNames();
  if (networkNames.length === 0) {
    console.log('No networks available');
    await waitForEnter();
    return;
  }

  const selected = await select('Select network', networkNames);
  const network = getNetwork(selected);

  const poaStep = network.steps.initPoa;
  const bootnodeStep = network.steps.initBootnode;
  if (poaStep.status !== 'completed' || bootnodeStep.status !== 'completed') {
    console.log('initPoa and initBootnode must be completed before adding beacon nodes');
    await waitForEnter();
    return;
  }

  if (!(await requireClConfig(network))) {
    return;
  }

  const nodeName = await prompt('Node name (leave empty for auto-generated): ') || null;

  console.log(`\nAdding beacon node to network: ${selected}`);
  if (nodeName) {
    console.log(`Node name: ${nodeName}`);
  }

  const confirmed = await confirm('Proceed?');
  if (!confirmed) {
    return;
  }

  try {
    const result = await addBeaconNode(selected, nodeName);
    console.log(`\nBeacon node added successfully!`);
    console.log(`  Name: ${result.name}`);
    console.log(`  IP: ${result.ip}`);
    console.log(`  ENODE: ${result.enode}`);
  } catch (error) {
    console.error(`\nError:`, error.message);
  }
  await waitForEnter();
}

/**
 * Add validator node menu - allows adding multiple nodes one by one
 */
async function addValidatorNodeMenu() {
  sectionHeader('Add Validator Node');

  const networkNames = listNetworkNames();
  if (networkNames.length === 0) {
    console.log('No networks available');
    await waitForEnter();
    return;
  }

  const selected = await select('Select network', networkNames);
  const network = getNetwork(selected);

  const poaStep = network.steps.initPoa;
  const bootnodeStep = network.steps.initBootnode;
  
  if (!(await requireClConfig(network))) {
    return;
  }

  let poaEnode = null;
  let bootnodeEnr = null;

  if (poaStep.status === 'completed' && poaStep.data) {
    poaEnode = poaStep.data.cliqueEnode;
  } else {
    console.log('\nPOA enode is required. Please provide:');
    poaEnode = await prompt('POA ENODE: ');
    if (!poaEnode) {
      console.log('POA ENODE is required');
      await waitForEnter();
      return;
    }
  }

  if (bootnodeStep.status === 'completed' && bootnodeStep.data) {
    bootnodeEnr = bootnodeStep.data.bootnodeEnr;
  } else {
    console.log('\nBootnode ENR is required. Please provide:');
    bootnodeEnr = await prompt('Bootnode ENR: ');
    if (!bootnodeEnr) {
      console.log('Bootnode ENR is required');
      await waitForEnter();
      return;
    }
  }

  // Allow adding multiple nodes one by one
  while (true) {
    console.log('\n--- Adding Validator Node ---');
    const nodeName = await prompt('Node name (leave empty for auto-generated, or "done" to finish): ');
    
    if (nodeName && nodeName.toLowerCase() === 'done') {
      break;
    }

    console.log('\nEnter validator key JSON:');
    console.log('  Option 1: Enter file path to validator key JSON file');
    console.log('  Option 2: Paste JSON content (paste all at once, then press Enter)');
    
    const inputMethod = await prompt('\nChoose method [1=file, 2=paste]: ') || '1';
    
    let validatorKeyJson = '';
    
    if (inputMethod === '1') {
      const filePath = await prompt('Enter file path to validator key JSON: ');
      if (!filePath) {
        console.log('File path is required');
        continue;
      }
      try {
        const fs = (await import('fs')).default;
        validatorKeyJson = fs.readFileSync(filePath, 'utf8').trim();
      } catch (error) {
        console.log(`Error reading file: ${error.message}`);
        continue;
      }
    } else {
      console.log('\nPaste validator key JSON (paste the entire JSON, then press Enter):');
      validatorKeyJson = await prompt('');
      validatorKeyJson = validatorKeyJson.trim();
    }

    if (!validatorKeyJson) {
      console.log('Validator key JSON is required');
      continue;
    }

    // Validate JSON
    try {
      JSON.parse(validatorKeyJson);
    } catch (error) {
      console.log('Invalid JSON format. Please try again.');
      continue;
    }

    const validatorPassword = await prompt('Validator password: ');
    if (!validatorPassword) {
      console.log('Validator password is required');
      continue;
    }

    console.log(`\nReview validator node:`);
    console.log(`  Network: ${selected}`);
    console.log(`  Node name: ${nodeName || 'auto-generated'}`);
    console.log(`  Password: ${'*'.repeat(validatorPassword.length)}`);

    const confirmed = await confirm('Proceed with creating this validator node?');
    if (!confirmed) {
      const continueAdding = await confirm('Continue adding more nodes?');
      if (!continueAdding) {
        break;
      }
      continue;
    }

    try {
      const result = await executeCreateValidator(
        selected,
        validatorKeyJson,
        validatorPassword,
        nodeName || null,
        poaEnode,
        bootnodeEnr
      );
      console.log(`\n✓ Validator node added successfully!`);
      console.log(`  Name: ${result.name}`);
      console.log(`  IP: ${result.ip || 'Pending...'}`);
    } catch (error) {
      console.error(`\n✗ Error:`, error.message);
    }

    const addMore = await confirm('\nAdd another validator node?');
    if (!addMore) {
      break;
    }
  }

  await waitForEnter();
}

/**
 * Ensure CL config exists before creating CL-related nodes
 */
function isClConfigReady(network) {
  const cl = network.config?.cl || {};
  return Boolean(
    cl.depositContractAddress &&
      cl.minGenesisActiveValidatorCount !== undefined &&
      cl.depositBlock !== undefined,
  );
}

async function requireClConfig(network) {
  if (isClConfigReady(network)) {
    return true;
  }
  console.log('\nCL configuration is required before creating this node.');
  console.log('Please run "Prepare CL config" first.');
  await waitForEnter();
  return false;
}

/**
 * Update CL config menu
 */
async function updateClConfigMenu() {
  sectionHeader('Update CL Configuration');

  const networkNames = listNetworkNames();
  if (networkNames.length === 0) {
    console.log('No networks available');
    await waitForEnter();
    return;
  }

  const selected = await select('Select network', networkNames);
  const network = getNetwork(selected);
  const clCurrent = network.config?.cl || {};

  console.log('\nCurrent CL Configuration:');
  displayKeyValue({
    CL_DEPOSIT_CONTRACT_ADDRESS: clCurrent.depositContractAddress || '0x4242424242424242424242424242424242424242',
    CL_DEPOSIT_CHAIN_ID: clCurrent.depositChainId ?? 84,
    CL_DEPOSIT_NETWORK_ID: clCurrent.depositNetworkId ?? 84,
    CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: clCurrent.minGenesisActiveValidatorCount ?? 8,
    CL_DEPOSIT_BLOCK: clCurrent.depositBlock ?? 0,
    CL_GENESIS_STATE_URL: clCurrent.genesisStateUrl || '(not set)',
    CL_SECONDS_PER_SLOT: clCurrent.secondsPerSlot ?? 5,
    CL_SLOTS_PER_EPOCH: clCurrent.slotsPerEpoch ?? 5,
    CL_SECONDS_PER_ETH1_BLOCK: clCurrent.secondsPerEth1Block ?? 5,
  });

  console.log('\nEnter new CL configuration values (leave empty to keep current):');
  const clDepositContractAddress = await prompt(`CL Deposit Contract Address [${clCurrent.depositContractAddress || '0x4242424242424242424242424242424242424242'}]: `);
  const clDepositChainId = await prompt(`CL Deposit Chain ID [${clCurrent.depositChainId ?? 84}]: `);
  const clDepositNetworkId = await prompt(`CL Deposit Network ID [${clCurrent.depositNetworkId ?? 84}]: `);
  const clMinGenesisActiveValidatorCount = await prompt(`CL Min Genesis Active Validator Count [${clCurrent.minGenesisActiveValidatorCount ?? 8}]: `);
  const clDepositBlock = await prompt(`CL Deposit Block [${clCurrent.depositBlock ?? 0}]: `);
  const clGenesisStateUrl = await prompt(`CL Genesis State URL [${clCurrent.genesisStateUrl || ''}]: `);
  const clSecondsPerSlot = await prompt(`CL Seconds Per Slot [${clCurrent.secondsPerSlot ?? 5}]: `);
  const clSlotsPerEpoch = await prompt(`CL Slots Per Epoch [${clCurrent.slotsPerEpoch ?? 5}]: `);
  const clSecondsPerEth1Block = await prompt(`CL Seconds Per Eth1 Block [${clCurrent.secondsPerEth1Block ?? 5}]: `);

  const updatedCl = {
    depositContractAddress: clDepositContractAddress || clCurrent.depositContractAddress || '0x4242424242424242424242424242424242424242',
    depositChainId: clDepositChainId ? parseInt(clDepositChainId, 10) : (clCurrent.depositChainId ?? 84),
    depositNetworkId: clDepositNetworkId ? parseInt(clDepositNetworkId, 10) : (clCurrent.depositNetworkId ?? 84),
    minGenesisActiveValidatorCount: clMinGenesisActiveValidatorCount ? parseInt(clMinGenesisActiveValidatorCount, 10) : (clCurrent.minGenesisActiveValidatorCount ?? 8),
    depositBlock: clDepositBlock ? parseInt(clDepositBlock, 10) : (clCurrent.depositBlock ?? 0),
    genesisStateUrl: clGenesisStateUrl !== '' ? (clGenesisStateUrl || null) : clCurrent.genesisStateUrl,
    secondsPerSlot: clSecondsPerSlot ? parseInt(clSecondsPerSlot, 10) : (clCurrent.secondsPerSlot ?? 5),
    slotsPerEpoch: clSlotsPerEpoch ? parseInt(clSlotsPerEpoch, 10) : (clCurrent.slotsPerEpoch ?? 5),
    secondsPerEth1Block: clSecondsPerEth1Block ? parseInt(clSecondsPerEth1Block, 10) : (clCurrent.secondsPerEth1Block ?? 5),
  };

  console.log('\nUpdated CL Configuration:');
  displayKeyValue({
    CL_DEPOSIT_CONTRACT_ADDRESS: updatedCl.depositContractAddress,
    CL_DEPOSIT_CHAIN_ID: updatedCl.depositChainId,
    CL_DEPOSIT_NETWORK_ID: updatedCl.depositNetworkId,
    CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: updatedCl.minGenesisActiveValidatorCount,
    CL_DEPOSIT_BLOCK: updatedCl.depositBlock,
    CL_GENESIS_STATE_URL: updatedCl.genesisStateUrl || '(not set)',
    CL_SECONDS_PER_SLOT: updatedCl.secondsPerSlot,
    CL_SLOTS_PER_EPOCH: updatedCl.slotsPerEpoch,
    CL_SECONDS_PER_ETH1_BLOCK: updatedCl.secondsPerEth1Block,
  });

  const confirmed = await confirm('\nSave these CL configuration changes?');
  if (!confirmed) {
    return;
  }

  // Update network config (structured CL)
  network.config = network.config || {};
  network.config.cl = {...(network.config.cl || {}), ...updatedCl};
  saveNetwork(selected, network);
  console.log('\n✓ CL configuration updated successfully!');

  // Ask if user wants to update existing beacon nodes
  const hasBeaconNodes =
    (network.nodes?.bootnode && network.nodes.bootnode.length > 0) ||
    (network.nodes?.beacon && network.nodes.beacon.length > 0) ||
    (network.nodes?.beaconNodes && network.nodes.beaconNodes.length > 0) ||
    (network.nodes?.validators && network.nodes.validators.length > 0);

  if (hasBeaconNodes) {
    const updateNodes = await confirm('\nUpdate existing beacon nodes (bootnode, beacon, validators) with new CL config?');
    if (updateNodes) {
      const envUpdates = {
        CL_DEPOSIT_CONTRACT_ADDRESS: updatedCl.depositContractAddress,
        CL_DEPOSIT_CHAIN_ID: String(updatedCl.depositChainId),
        CL_DEPOSIT_NETWORK_ID: String(updatedCl.depositNetworkId),
        CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: String(updatedCl.minGenesisActiveValidatorCount),
        CL_DEPOSIT_BLOCK: String(updatedCl.depositBlock),
        CL_SECONDS_PER_SLOT: String(updatedCl.secondsPerSlot),
        CL_SLOTS_PER_EPOCH: String(updatedCl.slotsPerEpoch),
        CL_SECONDS_PER_ETH1_BLOCK: String(updatedCl.secondsPerEth1Block),
        ...(updatedCl.genesisStateUrl ? {CL_GENESIS_STATE_URL: updatedCl.genesisStateUrl} : {}),
      };

      try {
        const result = await updateForkForAllNodes(selected, envUpdates);
        if (result.success) {
          console.log('\n✓ All beacon nodes updated successfully!');
        } else {
          console.log(`\nCompleted with ${result.errors.length} error(s)`);
        }
      } catch (error) {
        console.error(`\nError updating nodes:`, error.message);
      }
    }
  }

  await waitForEnter();
}

/**
 * Prepare CL config (wrapper for clarity)
 */
async function prepareClConfigMenu() {
  await updateClConfigMenu();
}

/**
 * Create blockscout menu
 */
async function createBlockscoutMenu() {
  sectionHeader('Create Blockscout');

  const networkNames = listNetworkNames();
  if (networkNames.length === 0) {
    console.log('No networks available');
    await waitForEnter();
    return;
  }

  const selected = await select('Select network', networkNames);
  const network = getNetwork(selected);
  const poaStep = network.steps.initPoa;
  const cliqueRpc = poaStep.status === 'completed' && poaStep.data ? `http://${poaStep.data.cliqueIp}:8545` : '';

  const config = network.config || {};
  const el = config.el || {};
  const elExplorer = config.elExplorer || {};

  const rpcInput = await prompt(`EL RPC URL [${elExplorer.elRpcUrl || cliqueRpc || 'required'}]: `);
  const elRpcUrl = rpcInput || elExplorer.elRpcUrl || cliqueRpc;
  if (!elRpcUrl) {
    console.log('EL RPC URL is required');
    await waitForEnter();
    return;
  }

  console.log('\nReview Blockscout creation:');
  console.log(`  Network: ${selected}`);
  console.log(`  EL RPC URL: ${elRpcUrl}`);
  console.log(`  Network ID: ${elExplorer.networkId || el.networkId || 84} (from config)`);
  console.log(`  Network Name: ${elExplorer.networkName || el.networkName || `${selected} Network`} (from config)`);

  const confirmed = await confirm('\nProceed with creating Blockscout?');
  if (!confirmed) {
    return;
  }

  try {
    await executeCreateBlockscout(selected, elRpcUrl);
    console.log('\nBlockscout created successfully!');
  } catch (error) {
    console.error('\nError:', error.message);
  }
  await waitForEnter();
}

/**
 * Create dora menu
 */
async function createDoraMenu() {
  sectionHeader('Create Dora');

  const networkNames = listNetworkNames();
  if (networkNames.length === 0) {
    console.log('No networks available');
    await waitForEnter();
    return;
  }

  const selected = await select('Select network', networkNames);
  const network = getNetwork(selected);

  const beaconStep = network.steps.initBeacon;
  const defaultClRpc = beaconStep.status === 'completed' && beaconStep.data ? `http://${beaconStep.data.beaconIp}:3500` : '';
  const defaultElRpc = beaconStep.status === 'completed' && beaconStep.data ? `http://${beaconStep.data.beaconIp}:8545` : '';

  const clRpcUrl = await prompt(`CL RPC URL [${defaultClRpc || 'required'}]: `) || defaultClRpc;
  const elRpcUrl = await prompt(`EL RPC URL [${defaultElRpc || 'required'}]: `) || defaultElRpc;

  if (!clRpcUrl || !elRpcUrl) {
    console.log('Both CL and EL RPC URLs are required');
    await waitForEnter();
    return;
  }

  console.log('\nReview Dora creation:');
  console.log(`  Network: ${selected}`);
  console.log(`  CL RPC URL: ${clRpcUrl}`);
  console.log(`  EL RPC URL: ${elRpcUrl}`);

  const confirmed = await confirm('\nProceed with creating Dora?');
  if (!confirmed) {
    return;
  }

  try {
    await executeCreateDora(selected, clRpcUrl, elRpcUrl);
    console.log('\nDora created successfully!');
  } catch (error) {
    console.error('\nError:', error.message);
  }
  await waitForEnter();
}

/**
 * Update Blockscout RPC (from main menu)
 */
async function updateBlockscoutMenu() {
  sectionHeader('Update Blockscout RPC');

  const networkNames = listNetworkNames();
  if (networkNames.length === 0) {
    console.log('No networks available');
    await waitForEnter();
    return;
  }

  const selected = await select('Select network', networkNames);
  const network = getNetwork(selected);
  const poaStep = network.steps.initPoa;
  
  // Get clique RPC as default
  const cliqueRpc = poaStep.status === 'completed' && poaStep.data ? `http://${poaStep.data.cliqueIp}:8545` : '';
  
  // Get existing RPC from config (support both old and new structure)
  const config = network.config || {};
  const elExplorer = config.elExplorer || {};
  const existingRpc = elExplorer.elRpcUrl || config.elRpcUrl || cliqueRpc;
  
  const currentBlockscout = (network.nodes?.blockscout || [])[0];

  if (currentBlockscout?.ip) {
    console.log(`Current Blockscout IP: ${currentBlockscout.ip}`);
  }
  
  if (cliqueRpc && existingRpc === cliqueRpc) {
    console.log(`\nCurrent RPC: ${existingRpc} (from Clique node)`);
  } else if (existingRpc) {
    console.log(`\nCurrent RPC: ${existingRpc}`);
  }

  const rpcInput = await prompt(`New EL RPC URL [${existingRpc || cliqueRpc || 'required'}]: `);
  const newRpc = rpcInput || existingRpc || cliqueRpc;
  if (!newRpc) {
    console.log('EL RPC URL is required');
    await waitForEnter();
    return;
  }

  // Support both old and new config structure for networkId and networkName
  const el = config.el || {};
  const networkIdDefault = elExplorer.networkId || el.networkId || config.networkId || 84;
  const networkNameDefault = elExplorer.networkName || el.networkName || config.networkName || `${selected} Network`;
  
  const networkIdInput = await prompt(`Network ID [${networkIdDefault}]: `);
  const networkId = networkIdInput ? Number(networkIdInput) : null; // null means use default from config

  console.log('\nReview Blockscout update:');
  console.log(`  Network: ${selected}`);
  console.log(`  New EL RPC URL: ${newRpc}`);
  console.log(`  Network ID: ${networkId || networkIdDefault} (${networkId ? 'custom' : 'from config'})`);
  console.log(`  Network Name: ${networkNameDefault} (from config)`);

  const confirmed = await confirm('\nProceed with updating Blockscout?');
  if (!confirmed) {
    return;
  }

  try {
    await executeUpdateBlockscout(
      selected,
      newRpc,
      networkId, // null means use default from config
      null, // null means use default from config
    );
    console.log('\nBlockscout RPC updated successfully!');
  } catch (error) {
    console.error('\nError:', error.message);
  }
  await waitForEnter();
}

/**
 * Update fork menu
 */
async function updateForkMenu() {
  sectionHeader('Update Fork Configuration');

  const networkNames = listNetworkNames();
  if (networkNames.length === 0) {
    console.log('No networks available');
    await waitForEnter();
    return;
  }

  const selected = await select('Select network', networkNames);
  const network = getNetwork(selected);

  console.log('\nEnter environment variables to update (key=value format)');
  console.log('Press Enter with empty line to finish');
  console.log('\nCommon fork variables:');
  console.log('  - EL_TERMINAL_TOTAL_DIFFICULTY');
  console.log('  - CL_TERMINAL_TOTAL_DIFFICULTY');
  console.log('  - EL_SHANGHAI_TIME');
  console.log('  - CL_CAPELLA_FORK_EPOCH');
  console.log('  - EL_CANCUN_TIME');
  console.log('  - CL_DENEB_FORK_EPOCH');
  console.log('  - EL_PRAGUE_TIME');
  console.log('  - CL_ELECTRA_FORK_EPOCH');
  console.log('  - GETH_DOCKER_IMAGE');
  console.log('  - LH_IMAGE');

  const envUpdates = {};
  while (true) {
    const line = await prompt('\nEnter key=value (or empty to finish): ');
    if (!line.trim()) {
      break;
    }
    const equalIndex = line.indexOf('=');
    if (equalIndex === -1) {
      console.log('Invalid format. Use key=value');
      continue;
    }
    const key = line.slice(0, equalIndex).trim();
    const value = line.slice(equalIndex + 1).trim();
    if (key) {
      envUpdates[key] = value;
    }
  }

  if (Object.keys(envUpdates).length === 0) {
    console.log('No updates specified');
    await waitForEnter();
    return;
  }

  console.log('\nEnvironment updates to apply:');
  displayKeyValue(envUpdates);
  console.log('\nNote: This will update beacon and validator nodes only (clique and bootnode will be skipped)');
  console.log('      Updates will be done sequentially with delays between nodes');

  // Ask for delay time (optional)
  const delayInput = await prompt('\nDelay between updates in seconds [5 for validators, 3 for beacon]: ');
  const delaySeconds = delayInput ? parseFloat(delayInput) : null;
  const delayMs = delaySeconds ? delaySeconds * 1000 : null;

  if (delayMs) {
    console.log(`Using ${delaySeconds}s delay between updates`);
  } else {
    console.log('Using default delays: 5s for validators, 3s for beacon nodes');
  }

  const confirmed = await confirm('\nProceed with updating beacon and validator nodes?');
  if (!confirmed) {
    return;
  }

  try {
    const result = await updateForkForAllNodes(selected, envUpdates, delayMs);
    if (result.success) {
      console.log('\n✓ All beacon and validator nodes updated successfully!');
    } else {
      console.log(`\nCompleted with ${result.errors.length} error(s)`);
    }
  } catch (error) {
    console.error(`\nError:`, error.message);
  }
  await waitForEnter();
}

/**
 * Manage network config
 */
async function manageNetworkConfigMenu() {
  sectionHeader('Manage Network Configuration');

  const networkNames = listNetworkNames();
  if (networkNames.length === 0) {
    console.log('No networks available');
    await waitForEnter();
    return;
  }

  const selected = await select('Select network', networkNames);
  const network = getNetwork(selected);

  const configSections = [
    {label: 'Review all config', value: 'review'},
    {label: 'Update Server config', value: 'server'},
    {label: 'Update EL config', value: 'el'},
    {label: 'Update CL config', value: 'cl'},
    {label: 'Update EL Explorer (Blockscout) config', value: 'elExplorer'},
    {label: 'Update CL Explorer (Dora) config', value: 'clExplorer'},
    {label: 'Back to main menu', value: 'back'},
  ];

  while (true) {
    const action = await select('\nSelect action', configSections);
    if (action === 'back') {
      break;
    }

    if (action === 'review') {
      await reviewNetworkConfig(selected);
    } else {
      await updateConfigSection(selected, action);
    }
  }
}

/**
 * Review network config
 */
async function reviewNetworkConfig(networkName) {
  sectionHeader(`Review Configuration: ${networkName}`);
  const network = getNetwork(networkName);
  const config = network.config || getDefaultConfig();

  console.log('\n=== Server Configuration ===');
  displayKeyValue(config.server || {});

  console.log('\n=== EL (Execution Layer) Configuration ===');
  displayKeyValue(config.el || {});

  console.log('\n=== CL (Consensus Layer) Configuration ===');
  displayKeyValue(config.cl || {});

  console.log('\n=== EL Explorer (Blockscout) Configuration ===');
  displayKeyValue(config.elExplorer || {});

  console.log('\n=== CL Explorer (Dora) Configuration ===');
  displayKeyValue(config.clExplorer || {});

  if (config.forkConfig && Object.keys(config.forkConfig).length > 0) {
    console.log('\n=== Additional Fork Configuration ===');
    displayKeyValue(config.forkConfig);
  }

  await waitForEnter();
}

/**
 * Update config section
 */
async function updateConfigSection(networkName, section) {
  sectionHeader(`Update ${section} Configuration`);

  const current = getNetworkConfigSection(networkName, section);
  const updates = {};

  switch (section) {
    case 'server':
      console.log('\nCurrent Server Configuration:');
      displayKeyValue(current);
      const projectId = await prompt(`Project ID [${current.projectId || ''}]: `);
      const zone = await prompt(`Zone [${current.zone || 'asia-northeast1-a'}]: `);
      const sshUser = await prompt(`SSH User [${current.sshUser || 'linux'}]: `);
      if (projectId) updates.projectId = projectId;
      if (zone) updates.zone = zone;
      if (sshUser) updates.sshUser = sshUser;
      break;

    case 'el':
      console.log('\nCurrent EL Configuration:');
      displayKeyValue(current);
      const chainId = await prompt(`Chain ID [${current.chainId || 84}]: `);
      const networkId = await prompt(`Network ID [${current.networkId || 84}]: `);
      const networkName = await prompt(`Network Name [${current.networkName || ''}]: `);
      const gethImage = await prompt(`Geth Image [${current.gethImage || 'ethereum/client-go:v1.11.6'}]: `);
      if (chainId) updates.chainId = parseInt(chainId, 10);
      if (networkId) updates.networkId = parseInt(networkId, 10);
      if (networkName) updates.networkName = networkName;
      if (gethImage) updates.gethImage = gethImage;
      break;

    case 'cl':
      console.log('\nCurrent CL Configuration:');
      displayKeyValue(current);
      const depositContract = await prompt(`Deposit Contract Address [${current.depositContractAddress || '0x4242424242424242424242424242424242424242'}]: `);
      const minGenesis = await prompt(`Min Genesis Validator Count [${current.minGenesisActiveValidatorCount || 8}]: `);
      const depositBlock = await prompt(`Deposit Block [${current.depositBlock || 0}]: `);
      const genesisStateUrl = await prompt(`Genesis State URL [${current.genesisStateUrl || ''}]: `);
      const lighthouseImage = await prompt(`Lighthouse Image [${current.lighthouseImage || 'sigp/lighthouse:v7.0.1'}]: `);
      if (depositContract) updates.depositContractAddress = depositContract;
      if (minGenesis) updates.minGenesisActiveValidatorCount = parseInt(minGenesis, 10);
      if (depositBlock) updates.depositBlock = parseInt(depositBlock, 10);
      if (genesisStateUrl !== '') updates.genesisStateUrl = genesisStateUrl || null;
      if (lighthouseImage) updates.lighthouseImage = lighthouseImage;
      break;

    case 'elExplorer':
      console.log('\nCurrent EL Explorer Configuration:');
      displayKeyValue(current);
      const explorerNetworkId = await prompt(`Network ID [${current.networkId || 84}]: `);
      const explorerNetworkName = await prompt(`Network Name [${current.networkName || ''}]: `);
      const elRpcUrl = await prompt(`EL RPC URL [${current.elRpcUrl || ''}]: `);
      if (explorerNetworkId) updates.networkId = parseInt(explorerNetworkId, 10);
      if (explorerNetworkName) updates.networkName = explorerNetworkName;
      if (elRpcUrl) updates.elRpcUrl = elRpcUrl;
      break;

    case 'clExplorer':
      console.log('\nCurrent CL Explorer Configuration:');
      displayKeyValue(current);
      const clRpcUrl = await prompt(`CL RPC URL [${current.clRpcUrl || ''}]: `);
      const clExplorerElRpcUrl = await prompt(`EL RPC URL [${current.elRpcUrl || ''}]: `);
      if (clRpcUrl) updates.clRpcUrl = clRpcUrl;
      if (clExplorerElRpcUrl) updates.elRpcUrl = clExplorerElRpcUrl;
      break;
  }

  if (Object.keys(updates).length === 0) {
    console.log('\nNo updates provided');
    await waitForEnter();
    return;
  }

  console.log('\nUpdates to apply:');
  displayKeyValue(updates);

  const confirmed = await confirm('\nApply these updates?');
  if (!confirmed) {
    return;
  }

  updateNetworkConfig(networkName, section, updates);
  console.log('\n✓ Configuration updated successfully!');
  await waitForEnter();
}

/**
 * Delete a network
 */
async function deleteNetworkMenu() {
  sectionHeader('Delete Network');

  const networkNames = listNetworkNames();
  if (networkNames.length === 0) {
    console.log('No networks available');
    await waitForEnter();
    return;
  }

  const selected = await select('Select network to delete', networkNames);
  const confirmed = await confirm(`\nAre you sure you want to delete network "${selected}"? This cannot be undone.`);
  if (!confirmed) {
    console.log('Cancelled');
    return;
  }

  const currentNetwork = getCurrentNetwork();
  if (selected === currentNetwork) {
    clearCurrentNetwork();
  }

  deleteNetwork(selected);
  console.log(`\nNetwork "${selected}" deleted`);
  await waitForEnter();
}

/**
 * Restore state on startup
 */
function restoreState() {
  const currentNetwork = getCurrentNetwork();
  if (currentNetwork) {
    const network = getNetwork(currentNetwork);
    if (network) {
      console.log(`Restored state: Current network is "${currentNetwork}"`);
      const status = getNetworkStatus(currentNetwork);
      console.log(`  Status: ${status.status}, Progress: ${status.progress}`);
      return true;
    } else {
      console.log('Warning: Current network not found in database');
    }
  }
  return false;
}

/**
 * Main application loop
 */
async function main() {
  console.clear();
  console.log('POS Test Network Manager\n');
  
  // Restore state from DB
  restoreState();
  console.log();

  while (true) {
    try {
      const choice = await showMainMenu();

      switch (choice) {
        case 'Create new network':
          await createNewNetwork();
          break;
        case 'List networks':
          await listNetworks();
          break;
        case 'Switch network':
          await switchNetwork();
          break;
        case 'View network details':
          await viewNetworkDetails();
          break;
        case 'Manage network config':
          await manageNetworkConfigMenu();
          break;
      case 'Prepare CL config':
        await prepareClConfigMenu();
        break;
      case 'Add bootnode':
        await addBootnodeMenu();
        break;
        case 'Add beacon node':
          await addBeaconNodeMenu();
          break;
        case 'Add validator node':
          await addValidatorNodeMenu();
          break;
      case 'Create blockscout':
        await createBlockscoutMenu();
        break;
      case 'Create dora':
        await createDoraMenu();
        break;
        case 'Update CL config':
          await updateClConfigMenu();
          break;
        case 'Update blockscout RPC':
          await updateBlockscoutMenu();
          break;
        case 'Update fork (beacon & validator)':
          await updateForkMenu();
          break;
        case 'Delete network':
          await deleteNetworkMenu();
          break;
        case 'Exit':
          console.log('\nGoodbye!');
          process.exit(0);
          break;
        default:
          console.log('Invalid choice');
      }
      console.clear();
    } catch (error) {
      if (error.message === 'Invalid selection' || error.message.includes('Cancelled')) {
        // User cancelled, continue
        continue;
      }
      console.error('\nError:', error.message);
      await waitForEnter();
      console.clear();
    }
  }
}

// Run the application
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
