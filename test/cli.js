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

// External dependencies
import axios from 'axios';

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
    'Exit',
  ];

  return await select('Main Menu', options);
}

/**
 * Network-specific menu (shown after switching to a network)
 */
async function showNetworkMenu() {
  const currentNetwork = getCurrentNetwork();
  if (!currentNetwork) {
    console.log('No network selected. Please switch to a network first.');
    await waitForEnter();
    return;
  }

  separator();
  console.log(`  Network: ${currentNetwork}`);
  separator();
  const status = getNetworkStatus(currentNetwork);
  console.log(`Status: ${status.status} | Progress: ${status.progress}`);
  console.log();

  const options = [
    'View network details',
    'Manage network config',
    'Prepare CL config',
    'Manage network steps',
    'Add execution node',
    'Add bootnode',
    'Add beacon node',
    'Add validator node',
    'Create blockscout',
    'Create dora',
    'Update CL config',
    'Update blockscout',
    'Update fork (beacon & validator)',
    'Delete network',
    'Back to main menu',
  ];

  return await select('Network Menu', options);
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

  const confirmed = await confirm('\nCreate network with these settings?', true);
  if (!confirmed) {
    console.log('Cancelled');
    return;
  }

  const network = initNetwork(name, config);
  console.log(`\nNetwork "${name}" created successfully!`);

  // Ask if user wants to set as current
  const setCurrent = await confirm('Set as current network?', true);
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
 * Switch current network and enter network menu
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
  
  // Enter network menu
  await networkMenu();
}

/**
 * Network menu loop
 */
async function networkMenu() {
  while (true) {
    try {
      const choice = await showNetworkMenu();

      switch (choice) {
        case 'View network details':
          await viewNetworkDetails();
          break;
        case 'Manage network config':
          await manageNetworkConfigMenu();
          break;
        case 'Prepare CL config':
          await prepareClConfigMenu();
          break;
        case 'Manage network steps':
          await manageNetworkSteps();
          break;
        case 'Add execution node':
          await addExecutionNodeMenu();
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
        case 'Update blockscout':
          await updateBlockscoutMenu();
          break;
        case 'Update fork (beacon & validator)':
          await updateForkMenu();
          break;
        case 'Delete network':
          await deleteNetworkMenu();
          break;
        case 'Back to main menu':
          return;
        default:
          console.log('Invalid choice');
      }
      console.clear();
    } catch (error) {
      if (error.message === 'Invalid selection' || error.message.includes('Cancelled')) {
        continue;
      }
      console.error('\nError:', error.message);
      await waitForEnter();
      console.clear();
    }
  }
}

/**
 * View network details (can be called from main menu or network menu)
 */
async function viewNetworkDetails() {
  let selected = getCurrentNetwork();
  
  // If called from main menu and no current network, allow selection
  if (!selected) {
    const networkNames = listNetworkNames();
    if (networkNames.length === 0) {
      console.log('No networks available');
      await waitForEnter();
      return;
    }
    selected = await select('Select network to view', networkNames);
  }

  sectionHeader(`Network Details: ${selected}`);
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
  const selected = getCurrentNetwork();
  if (!selected) {
    console.log('No network selected');
    await waitForEnter();
    return;
  }

  sectionHeader(`Manage Network Steps: ${selected}`);
  const network = getNetwork(selected);

  const stepOptions = [
    {label: 'Init POA', value: 'initPoa', func: executeInitPoa},
    {label: 'Init Bootnode', value: 'initBootnode', func: executeInitBootnode},
    {label: 'Initial Flow (POA only)', value: 'initialFlow', func: null},
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
      console.log('\nAfter this, you can deploy deposit contract, then create bootnode, beacon bootnode, and validators.');
      console.log('You can also create Blockscout or Dora explorers from the main menu.');

      const confirmed = await confirm('\nProceed with initial flow?', true);
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


    // Handle updateBlockscout (not a step, but menu item)
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
      const blockTransformerDefault = elExplorer.blockTransformer || 'clique';

      const networkIdInput = await prompt(`Network ID [${networkIdDefault}]: `);
      const networkNameInput = await prompt(`Network Name [${networkNameDefault}]: `);
      const blockTransformerInput = await prompt(`Block Transformer (e.g., clique, base, optimism) [${blockTransformerDefault}]: `);
      const blockTransformer = blockTransformerInput || blockTransformerDefault;

      const confirmed = await confirm('\nProceed with updating Blockscout?', true);
      if (!confirmed) {
        continue;
      }

      try {
        await executeUpdateBlockscout(
          selected,
          newRpc,
          blockTransformer,
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
    if (action === 'initBootnode' || action === 'initBeaconBootnode') {
      const poaStep = network.steps.initPoa;
      const bootnodeStep = network.steps.initBootnode;
      
      let poaEnode = null;
      let bootnodeEnr = null;

      if (action === 'initBootnode') {
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

      if (action === 'initBeaconBootnode') {
        if (poaStep.status !== 'completed' || !poaStep.data) {
          console.log('\nPOA enode is required. Please provide:');
          poaEnode = await prompt('POA ENODE: ');
          if (!poaEnode) {
            console.log('POA ENODE is required');
            await waitForEnter();
            continue;
          }
        }
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
    }

    const stepOption = stepOptions.find((opt) => opt.value === action);
    if (!stepOption || !stepOption.func) {
      continue;
    }

    // Check prerequisites
    const step = network.steps[action];
    if (step.status === 'completed') {
      const overwrite = await confirm(`Step "${action}" is already completed. Re-run?`, true);
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

    const confirmed = await confirm('\nProceed with this step?', true);
    if (!confirmed) {
      continue;
    }

    try {
      if (action === 'initBootnode') {
        const poaStep = network.steps.initPoa;
        const poaEnode = poaStep.status === 'completed' && poaStep.data ? poaStep.data.cliqueEnode : null;
        await executeInitBootnode(selected, poaEnode);
      } else if (action === 'initBeaconBootnode') {
        const poaStep = network.steps.initPoa;
        const bootnodeStep = network.steps.initBootnode;
        const poaEnode = poaStep.status === 'completed' && poaStep.data ? poaStep.data.cliqueEnode : null;
        const bootnodeEnr = bootnodeStep.status === 'completed' && bootnodeStep.data ? bootnodeStep.data.bootnodeEnr : null;
        await executeInitBeaconBootnode(selected, poaEnode, bootnodeEnr);
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
  const selected = getCurrentNetwork();
  if (!selected) {
    console.log('No network selected');
    await waitForEnter();
    return;
  }

  sectionHeader(`Add Execution Node: ${selected}`);
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

  const confirmed = await confirm('Proceed?', true);
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
  const selected = getCurrentNetwork();
  if (!selected) {
    console.log('No network selected');
    await waitForEnter();
    return;
  }

  sectionHeader(`Add Bootnode: ${selected}`);
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

  const confirmed = await confirm('Proceed?', true);
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
  const selected = getCurrentNetwork();
  if (!selected) {
    console.log('No network selected');
    await waitForEnter();
    return;
  }

  sectionHeader(`Add Beacon Node: ${selected}`);
  const network = getNetwork(selected);

  const poaStep = network.steps.initPoa;
  const bootnodeStep = network.steps.initBootnode;
  if (poaStep.status !== 'completed' || bootnodeStep.status !== 'completed') {
    console.log('initPoa and initBootnode must be completed before adding beacon nodes');
    await waitForEnter();
    return;
  }

  console.log('\nNote: Beacon bootnode (initBeaconBootnode) is the main beacon node that validators peer to.');
  console.log('      Additional beacon nodes can be added here for redundancy.');

  if (!(await requireClConfig(network))) {
    return;
  }

  const nodeName = await prompt('Node name (leave empty for auto-generated): ') || null;
  const archiveMode = await confirm('Enable archive mode? (CL_ARCHIVE_MODE=true)', false);

  console.log(`\nAdding beacon node to network: ${selected}`);
  if (nodeName) {
    console.log(`Node name: ${nodeName}`);
  }
  if (archiveMode) {
    console.log(`Archive mode: enabled (CL_ARCHIVE_MODE=true)`);
  }

  const confirmed = await confirm('Proceed?', true);
  if (!confirmed) {
    return;
  }

  try {
    const result = await addBeaconNode(selected, nodeName, archiveMode);
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
  const selected = getCurrentNetwork();
  if (!selected) {
    console.log('No network selected');
    await waitForEnter();
    return;
  }

  sectionHeader(`Add Validator Node: ${selected}`);
  const network = getNetwork(selected);

  const poaStep = network.steps.initPoa;
  const bootnodeStep = network.steps.initBootnode;
  
  if (!(await requireClConfig(network))) {
    return;
  }

  // Get bootnode array - first node with enode is beacon node
  const bootnodes = network.nodes?.bootnode || [];
  const firstBootnode = bootnodes.length > 0 ? bootnodes.find(b => b.enode) || bootnodes[0] : null;

  let poaEnode = null;
  let bootnodeEnr = null;
  let beaconBootnodeEnode = null;

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

  // Get ENR from step or bootnode array
  if (bootnodeStep.status === 'completed' && bootnodeStep.data) {
    bootnodeEnr = bootnodeStep.data.bootnodeEnr;
  } else if (firstBootnode?.enr) {
    bootnodeEnr = firstBootnode.enr;
  } else {
    console.log('\nBootnode ENR is required. Please provide:');
    bootnodeEnr = await prompt('Bootnode ENR: ');
    if (!bootnodeEnr) {
      console.log('Bootnode ENR is required');
      await waitForEnter();
      return;
    }
  }

  // Get beacon bootnode enode from bootnode array (validators peer to this)
  if (firstBootnode?.enode) {
    beaconBootnodeEnode = firstBootnode.enode;
    console.log(`\nUsing beacon node from bootnode array: ${firstBootnode.name || 'beacon-bootnode'}`);
    console.log(`  ENODE: ${beaconBootnodeEnode}`);
  } else {
    console.log('\nBeacon node not found in bootnode array. Please create beacon node first.');
    await waitForEnter();
    return;
  }

  // Allow adding multiple nodes one by one
  while (true) {
    console.log('\n--- Adding Validator Node ---');
    const nodeName = await prompt('Node name (leave empty for auto-generated, or "done" to finish): ');
    
    if (nodeName && nodeName.toLowerCase() === 'done') {
      break;
    }

    // console.log('\nEnter validator key JSON:');
    // console.log('  Option 1: Enter file path to validator key JSON file');
    // console.log('  Option 2: Paste JSON content (paste all at once, then press Enter)');
    
    // const inputMethod = await prompt('\nChoose method [1=file, 2=paste]: ') || '1';
    
    let validatorKeyJson = '';

    console.log('\nPaste validator key JSON (paste the entire JSON, then press Enter):');
    validatorKeyJson = await prompt('');
    validatorKeyJson = validatorKeyJson.trim();

    // if (inputMethod === '1') {
    //   const filePath = await prompt('Enter file path to validator key JSON: ');
    //   if (!filePath) {
    //     console.log('File path is required');
    //     continue;
    //   }
    //   try {
    //     const fs = (await import('fs')).default;
    //     validatorKeyJson = fs.readFileSync(filePath, 'utf8').trim();
    //   } catch (error) {
    //     console.log(`Error reading file: ${error.message}`);
    //     continue;
    //   }
    // } else {
    //   console.log('\nPaste validator key JSON (paste the entire JSON, then press Enter):');
    //   validatorKeyJson = await prompt('');
    //   validatorKeyJson = validatorKeyJson.trim();
    // }

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

    const confirmed = await confirm('Proceed with creating this validator node?', true);
    if (!confirmed) {
      const continueAdding = await confirm('Continue adding more nodes?', true);
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
        bootnodeEnr,
        beaconBootnodeEnode
      );
      console.log(`\n✓ Validator node added successfully!`);
      console.log(`  Name: ${result.name}`);
      console.log(`  IP: ${result.ip || 'Pending...'}`);
    } catch (error) {
      console.error(`\n✗ Error:`, error.message);
    }

    const addMore = await confirm('\nAdd another validator node?', true);
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
    cl.CL_DEPOSIT_CONTRACT_ADDRESS &&
      cl.CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT !== undefined &&
      cl.CL_DEPOSIT_BLOCK !== undefined,
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
  const selected = getCurrentNetwork();
  if (!selected) {
    console.log('No network selected');
    await waitForEnter();
    return;
  }

  sectionHeader(`Update CL Configuration: ${selected}`);
  const network = getNetwork(selected);
  const clCurrent = network.config?.cl || {};

  console.log('\nCurrent CL Configuration:');
  displayKeyValue({
    CL_DEPOSIT_CONTRACT_ADDRESS: clCurrent.CL_DEPOSIT_CONTRACT_ADDRESS || '0x4242424242424242424242424242424242424242',
    CL_DEPOSIT_CHAIN_ID: clCurrent.CL_DEPOSIT_CHAIN_ID ?? 84,
    CL_DEPOSIT_NETWORK_ID: clCurrent.CL_DEPOSIT_NETWORK_ID ?? 84,
    CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: clCurrent.CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT ?? 8,
    CL_DEPOSIT_BLOCK: clCurrent.CL_DEPOSIT_BLOCK ?? 0,
    CL_GENESIS_STATE_URL: clCurrent.CL_GENESIS_STATE_URL || '(not set)',
    CL_SECONDS_PER_SLOT: clCurrent.CL_SECONDS_PER_SLOT ?? 5,
    CL_SLOTS_PER_EPOCH: clCurrent.CL_SLOTS_PER_EPOCH ?? 16,
    CL_SECONDS_PER_ETH1_BLOCK: clCurrent.CL_SECONDS_PER_ETH1_BLOCK ?? 5,
  });

  console.log('\nEnter new CL configuration values (leave empty to keep current):');
  const currentDepositContract = clCurrent.CL_DEPOSIT_CONTRACT_ADDRESS || '0x4242424242424242424242424242424242424242';
  const currentDepositChainId = clCurrent.CL_DEPOSIT_CHAIN_ID ?? 84;
  const currentDepositNetworkId = clCurrent.CL_DEPOSIT_NETWORK_ID ?? 84;
  const currentMinGenesis = clCurrent.CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT ?? 8;
  const currentDepositBlock = clCurrent.CL_DEPOSIT_BLOCK ?? 0;
  const currentGenesisStateUrl = clCurrent.CL_GENESIS_STATE_URL || '';
  const currentSecondsPerSlot = clCurrent.CL_SECONDS_PER_SLOT ?? 5;
  const currentSlotsPerEpoch = clCurrent.CL_SLOTS_PER_EPOCH ?? 16;
  const currentSecondsPerEth1Block = clCurrent.CL_SECONDS_PER_ETH1_BLOCK ?? 5;
  
  const clDepositContractAddress = await prompt(`CL Deposit Contract Address [${currentDepositContract}]: `);
  const clDepositChainId = await prompt(`CL Deposit Chain ID [${currentDepositChainId}]: `);
  const clDepositNetworkId = await prompt(`CL Deposit Network ID [${currentDepositNetworkId}]: `);
  const clMinGenesisActiveValidatorCount = await prompt(`CL Min Genesis Active Validator Count [${currentMinGenesis}]: `);
  const clDepositBlock = await prompt(`CL Deposit Block [${currentDepositBlock}]: `);
  const clGenesisStateUrl = await prompt(`CL Genesis State URL [${currentGenesisStateUrl}]: `);
  const clSecondsPerSlot = await prompt(`CL Seconds Per Slot [${currentSecondsPerSlot}]: `);
  const clSlotsPerEpoch = await prompt(`CL Slots Per Epoch [${currentSlotsPerEpoch}]: `);
  const clSecondsPerEth1Block = await prompt(`CL Seconds Per Eth1 Block [${currentSecondsPerEth1Block}]: `);

  // Store with env var names for direct use
  const updatedCl = {
    CL_DEPOSIT_CONTRACT_ADDRESS: clDepositContractAddress || clCurrent.CL_DEPOSIT_CONTRACT_ADDRESS || '0x4242424242424242424242424242424242424242',
    CL_DEPOSIT_CHAIN_ID: String(clDepositChainId ? parseInt(clDepositChainId, 10) : (clCurrent.CL_DEPOSIT_CHAIN_ID ? parseInt(clCurrent.CL_DEPOSIT_CHAIN_ID, 10) : 84)),
    CL_DEPOSIT_NETWORK_ID: String(clDepositNetworkId ? parseInt(clDepositNetworkId, 10) : (clCurrent.CL_DEPOSIT_NETWORK_ID ? parseInt(clCurrent.CL_DEPOSIT_NETWORK_ID, 10) : 84)),
    CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: String(clMinGenesisActiveValidatorCount ? parseInt(clMinGenesisActiveValidatorCount, 10) : (clCurrent.CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT ? parseInt(clCurrent.CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT, 10) : 8)),
    CL_DEPOSIT_BLOCK: String(clDepositBlock ? parseInt(clDepositBlock, 10) : (clCurrent.CL_DEPOSIT_BLOCK ? parseInt(clCurrent.CL_DEPOSIT_BLOCK, 10) : 0)),
    CL_SECONDS_PER_SLOT: String(clSecondsPerSlot ? parseInt(clSecondsPerSlot, 10) : (clCurrent.CL_SECONDS_PER_SLOT ? parseInt(clCurrent.CL_SECONDS_PER_SLOT, 10) : 5)),
    CL_SLOTS_PER_EPOCH: String(clSlotsPerEpoch ? parseInt(clSlotsPerEpoch, 10) : (clCurrent.CL_SLOTS_PER_EPOCH ? parseInt(clCurrent.CL_SLOTS_PER_EPOCH, 10) : 5)),
    CL_SECONDS_PER_ETH1_BLOCK: String(clSecondsPerEth1Block ? parseInt(clSecondsPerEth1Block, 10) : (clCurrent.CL_SECONDS_PER_ETH1_BLOCK ? parseInt(clCurrent.CL_SECONDS_PER_ETH1_BLOCK, 10) : 5)),
  };
  
  // Handle genesisStateUrl (optional, can be null)
  if (clGenesisStateUrl !== '') {
    updatedCl.CL_GENESIS_STATE_URL = clGenesisStateUrl || clCurrent.CL_GENESIS_STATE_URL || null;
  } else if (clCurrent.CL_GENESIS_STATE_URL) {
    updatedCl.CL_GENESIS_STATE_URL = clCurrent.CL_GENESIS_STATE_URL;
  }

  console.log('\nUpdated CL Configuration:');
  displayKeyValue({
    CL_DEPOSIT_CONTRACT_ADDRESS: updatedCl.CL_DEPOSIT_CONTRACT_ADDRESS,
    CL_DEPOSIT_CHAIN_ID: updatedCl.CL_DEPOSIT_CHAIN_ID,
    CL_DEPOSIT_NETWORK_ID: updatedCl.CL_DEPOSIT_NETWORK_ID,
    CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: updatedCl.CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT,
    CL_DEPOSIT_BLOCK: updatedCl.CL_DEPOSIT_BLOCK,
    CL_GENESIS_STATE_URL: updatedCl.CL_GENESIS_STATE_URL || '(not set)',
    CL_SECONDS_PER_SLOT: updatedCl.CL_SECONDS_PER_SLOT,
    CL_SLOTS_PER_EPOCH: updatedCl.CL_SLOTS_PER_EPOCH,
    CL_SECONDS_PER_ETH1_BLOCK: updatedCl.CL_SECONDS_PER_ETH1_BLOCK,
  });

  const confirmed = await confirm('\nSave these CL configuration changes?', true);
  if (!confirmed) {
    return;
  }

  // Update network config (structured CL)
  network.config = network.config || {};
  network.config.cl = {...(network.config.cl || {}), ...updatedCl};
  saveNetwork(selected, network);
  console.log('\n✓ CL configuration updated successfully!');

      // Ask if user wants to update existing beacon nodes
      const bootnodes = network.nodes?.bootnode || [];
      const hasBeaconBootnode = bootnodes.some(b => b.enode); // Beacon node in bootnode array
      const hasBeaconNodes =
        hasBeaconBootnode ||
        (network.nodes?.beacon && network.nodes.beacon.length > 0) ||
        (network.nodes?.validators && network.nodes.validators.length > 0);

  if (hasBeaconNodes) {
    const updateNodes = await confirm('\nUpdate existing beacon nodes (bootnode, beacon, validators) with new CL config?', true);
    if (updateNodes) {
      // Use the env var names directly from updatedCl
      const envUpdates = {
        ...updatedCl,
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
  const selected = getCurrentNetwork();
  if (!selected) {
    console.log('No network selected');
    await waitForEnter();
    return;
  }

  sectionHeader(`Create Blockscout: ${selected}`);
  const network = getNetwork(selected);
  const poaStep = network.steps.initPoa;
  const cliqueRpc = poaStep.status === 'completed' && poaStep.data ? `http://${poaStep.data.cliqueIp}:8545` : '';

  const config = network.config || {};
  const el = config.el || {};
  const elExplorer = config.elExplorer || {};

  const name = await prompt(`Blockscout name [${elExplorer.name || 'blockscout'}]: `) || elExplorer.name || 'blockscout';

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

  const confirmed = await confirm('\nProceed with creating Blockscout?', true);
  if (!confirmed) {
    return;
  }

  try {
    await executeCreateBlockscout(selected, elRpcUrl, name);
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
  const selected = getCurrentNetwork();
  if (!selected) {
    console.log('No network selected');
    await waitForEnter();
    return;
  }

  sectionHeader(`Create Dora: ${selected}`);
  const network = getNetwork(selected);

  // Try to get from bootnode array (first node with enode is beacon node)
  const bootnodes = network.nodes?.bootnode || [];
  const firstBootnode = bootnodes.length > 0 ? bootnodes.find(b => b.enode) || bootnodes[0] : null;
  
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
  
  const defaultClRpc = beaconIp ? `http://${beaconIp}:3500` : '';
  const defaultElRpc = beaconIp ? `http://${beaconIp}:8545` : '';

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

  const confirmed = await confirm('\nProceed with creating Dora?', true);
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
  const selected = getCurrentNetwork();
  if (!selected) {
    console.log('No network selected');
    await waitForEnter();
    return;
  }

  sectionHeader(`Update Blockscout RPC: ${selected}`);
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
  const blockTransformerDefault = elExplorer.blockTransformer || 'clique';
  
  const networkIdInput = await prompt(`Network ID [${networkIdDefault}]: `);
  const networkId = networkIdInput ? Number(networkIdInput) : null; // null means use default from config
  const blockTransformerInput = await prompt(`Block Transformer (e.g., clique, base, optimism) [${blockTransformerDefault}]: `);
  const blockTransformer = blockTransformerInput || blockTransformerDefault;

  console.log('\nReview Blockscout update:');
  console.log(`  Network: ${selected}`);
  console.log(`  New EL RPC URL: ${newRpc}`);
  console.log(`  Block Transformer: ${blockTransformer} (${blockTransformerInput ? 'custom' : 'from config/default'})`);
  console.log(`  Network ID: ${networkId || networkIdDefault} (${networkId ? 'custom' : 'from config'})`);
  console.log(`  Network Name: ${networkNameDefault} (from config)`);

  const confirmed = await confirm('\nProceed with updating Blockscout?', true);
  if (!confirmed) {
    return;
  }

  try {
    await executeUpdateBlockscout(
      selected,
      newRpc,
      blockTransformer,
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
 * Calculate EL timestamp from CL epoch
 * Formula: TIMESTAMP = GENESIS_TIME + (EPOCH * SLOTS_PER_EPOCH * SECONDS_PER_SLOT)
 */
async function calculateElTimeFromClEpoch(clEpoch, beaconRpcUrl) {
  try {
    const genesisResponse = await axios.get(`${beaconRpcUrl}/eth/v1/beacon/genesis`);
    const genesisTime = Number(genesisResponse.data.data.genesis_time);

    const specResponse = await axios.get(`${beaconRpcUrl}/eth/v1/config/spec`);
    const slotsPerEpoch = Number(specResponse.data.data.SLOTS_PER_EPOCH);
    const secondsPerSlot = Number(specResponse.data.data.SECONDS_PER_SLOT);

    const slotsTotal = clEpoch * slotsPerEpoch;
    const timestamp = genesisTime + slotsTotal * secondsPerSlot;

    return timestamp;
  } catch (error) {
    throw new Error(`Failed to calculate EL time from CL epoch: ${error.message}`);
  }
}

/**
 * Get beacon RPC URL for the network
 */
function getBeaconRpcUrl(network) {
  // Try to get from bootnode array (first node with enode is beacon node)
  const bootnodes = network.nodes?.bootnode || [];
  const firstBootnode = bootnodes.length > 0 ? bootnodes.find(b => b.enode) || bootnodes[0] : null;
  if (firstBootnode?.ip) {
    return `http://${firstBootnode.ip}:3500`;
  }

  // Backward compatibility: try old steps
  const beaconBootnodeStep = network.steps?.initBeaconBootnode;
  if (beaconBootnodeStep?.status === 'completed' && beaconBootnodeStep?.data?.beaconIp) {
    return `http://${beaconBootnodeStep.data.beaconIp}:3500`;
  }

  const beaconStep = network.steps?.initBeacon;
  if (beaconStep?.status === 'completed' && beaconStep?.data?.beaconIp) {
    return `http://${beaconStep.data.beaconIp}:3500`;
  }

  // Try validators (they also run beacon)
  const validators = network.nodes?.validators || [];
  if (validators.length > 0 && validators[0].ip) {
    return `http://${validators[0].ip}:3500`;
  }

  // Try config
  const clExplorer = network.config?.clExplorer;
  if (clExplorer?.clRpcUrl) {
    // Extract base URL from clRpcUrl
    let url = clExplorer.clRpcUrl;
    // Remove /eth path if present
    url = url.replace(/\/eth\/?.*$/, '');
    // Ensure it's just base URL without port if missing
    if (!url.includes(':3500') && !url.match(/:\d+$/)) {
      url = url.replace(/\/$/, '') + ':3500';
    }
    return url;
  }

  return null;
}

/**
 * Get current fork config values from network (for display purposes)
 * This is a simplified version that reads from config directly
 */
function getCurrentForkConfig(network) {
  const config = network.config || {};
  const cl = config.cl || {};
  const el = config.el || {};
  const forkConfig = {};
  
  // Get from forkConfig (already env var names)
  if (config.forkConfig) {
    Object.assign(forkConfig, config.forkConfig);
  }
  
  // Get from cl and el with env var names (only env var names, no backward compatibility needed here)
  Object.keys(cl).forEach(key => {
    if ((key.startsWith('CL_') || key.startsWith('EL_')) && !forkConfig[key]) {
      forkConfig[key] = cl[key];
    }
  });
  
  Object.keys(el).forEach(key => {
    if ((key.startsWith('CL_') || key.startsWith('EL_')) && !forkConfig[key]) {
      forkConfig[key] = el[key];
    }
  });
  
  return forkConfig;
}

/**
 * Update fork menu
 */
async function updateForkMenu() {
  const selected = getCurrentNetwork();
  if (!selected) {
    console.log('No network selected');
    await waitForEnter();
    return;
  }

  sectionHeader(`Update Fork Configuration: ${selected}`);
  const network = getNetwork(selected);

  // Get current fork config values
  const currentForkConfig = getCurrentForkConfig(network);

  // Get beacon RPC URL for auto-calculation
  const beaconRpcUrl = getBeaconRpcUrl(network);
  const canAutoCalculate = beaconRpcUrl !== null;

  // Display current values
  // Note: EL_TERMINAL_TOTAL_DIFFICULTY and CL_TERMINAL_TOTAL_DIFFICULTY are merged (same value)
  const commonForkVars = [
    'TERMINAL_TOTAL_DIFFICULTY', // Merged: applies to both EL and CL
    'EL_SHANGHAI_TIME',
    'CL_CAPELLA_FORK_EPOCH',
    'EL_CANCUN_TIME',
    'CL_DENEB_FORK_EPOCH',
    'EL_PRAGUE_TIME',
    'CL_ELECTRA_FORK_EPOCH',
    'GETH_DOCKER_IMAGE',
    'LH_IMAGE',
  ];

  console.log('\nCurrent fork configuration:');
  // Show TERMINAL_TOTAL_DIFFICULTY (merged) or individual values
  const elTtd = currentForkConfig.EL_TERMINAL_TOTAL_DIFFICULTY;
  const clTtd = currentForkConfig.CL_TERMINAL_TOTAL_DIFFICULTY;
  const mergedTtd = elTtd || clTtd;
  
  if (mergedTtd) {
    console.log(`  TERMINAL_TOTAL_DIFFICULTY=${mergedTtd} (applies to both EL and CL)`);
  }
  
  const hasOtherValues = commonForkVars.filter(key => key !== 'TERMINAL_TOTAL_DIFFICULTY').some(key => currentForkConfig[key]);
  if (hasOtherValues) {
    commonForkVars.forEach(key => {
      if (key !== 'TERMINAL_TOTAL_DIFFICULTY' && currentForkConfig[key]) {
        console.log(`  ${key}=${currentForkConfig[key]}`);
      }
    });
  }
  
  if (!mergedTtd && !hasOtherValues) {
    console.log('  (no fork configuration set yet)');
  }

  console.log('\nEnter environment variables to update (key=value format)');
  console.log('Press Enter with empty line to finish');
  console.log('Leave value empty to keep current value');
  console.log('\nCommon fork variables:');
  commonForkVars.forEach(key => {
    if (key === 'TERMINAL_TOTAL_DIFFICULTY') {
      console.log(`  - ${key} (applies to both EL_TERMINAL_TOTAL_DIFFICULTY and CL_TERMINAL_TOTAL_DIFFICULTY)`);
    } else {
      const note = key.includes('SHANGHAI') ? ' (auto-calculated from CL_CAPELLA_FORK_EPOCH)' :
                   key.includes('CANCUN') ? ' (auto-calculated from CL_DENEB_FORK_EPOCH and ethereum/client-go:v1.13.15)' :
                   key.includes('PRAGUE') ? ' (auto-calculated from CL_ELECTRA_FORK_EPOCH and ethereum/client-go:v1.15.9)' : '';
      console.log(`  - ${key}${note}`);
    }
  });
  
  if (canAutoCalculate) {
    console.log(`\n✓ Auto-calculation enabled (using beacon RPC: ${beaconRpcUrl})`);
    console.log('  When you enter CL_*_FORK_EPOCH, corresponding EL_*_TIME will be calculated automatically');
  } else {
    console.log('\n⚠ Auto-calculation disabled (beacon node not found)');
    console.log('  You need to manually enter both CL_*_FORK_EPOCH and EL_*_TIME');
  }

  const envUpdates = {};
  const epochToTimeMapping = {
    'CL_CAPELLA_FORK_EPOCH': 'EL_SHANGHAI_TIME',
    'CL_DENEB_FORK_EPOCH': 'EL_CANCUN_TIME',
    'CL_ELECTRA_FORK_EPOCH': 'EL_PRAGUE_TIME',
  };

  while (true) {
    // Show prompt with current value if exists
    const currentValueHint = Object.keys(currentForkConfig).length > 0 
      ? '\nOr enter a specific key to update (e.g., CL_CAPELLA_FORK_EPOCH=60)' 
      : '';
    const line = await prompt(`\nEnter key=value${currentValueHint} (or empty to finish): `);
    if (!line.trim()) {
      break;
    }
    const equalIndex = line.indexOf('=');
    if (equalIndex === -1) {
      console.log('Invalid format. Use key=value');
      continue;
    }
    const key = line.slice(0, equalIndex).trim();
    let value = line.slice(equalIndex + 1).trim();
    if (!key) {
      continue;
    }

    // If value is empty and current value exists, skip (keep current)
    if (!value && currentForkConfig[key]) {
      console.log(`  Keeping current value: ${key}=${currentForkConfig[key]}`);
      continue;
    }

    // If value is empty and no current value, skip this key
    if (!value) {
      console.log(`  Skipping ${key} (no value provided and no current value)`);
      continue;
    }

    // Handle merged TERMINAL_TOTAL_DIFFICULTY (applies to both EL and CL)
    if (key === 'TERMINAL_TOTAL_DIFFICULTY') {
      envUpdates.EL_TERMINAL_TOTAL_DIFFICULTY = value;
      envUpdates.CL_TERMINAL_TOTAL_DIFFICULTY = value;
      console.log(`  Set both EL_TERMINAL_TOTAL_DIFFICULTY and CL_TERMINAL_TOTAL_DIFFICULTY = ${value}`);
    } else {
      // Handle backward compatibility: if user enters EL_TERMINAL_TOTAL_DIFFICULTY or CL_TERMINAL_TOTAL_DIFFICULTY
      if (key === 'EL_TERMINAL_TOTAL_DIFFICULTY' || key === 'CL_TERMINAL_TOTAL_DIFFICULTY') {
        envUpdates.EL_TERMINAL_TOTAL_DIFFICULTY = value;
        envUpdates.CL_TERMINAL_TOTAL_DIFFICULTY = value;
        console.log(`  Set both EL_TERMINAL_TOTAL_DIFFICULTY and CL_TERMINAL_TOTAL_DIFFICULTY = ${value} (merged)`);
      } else {
        envUpdates[key] = value;
      }
    }

    // Auto-calculate EL time if CL epoch is provided
    if (canAutoCalculate && epochToTimeMapping[key] && !envUpdates[epochToTimeMapping[key]]) {
      const epoch = parseInt(value, 10);
      if (!isNaN(epoch)) {
        try {
          console.log(`\n  Calculating ${epochToTimeMapping[key]} from ${key}=${epoch}...`);
          const calculatedTime = await calculateElTimeFromClEpoch(epoch, beaconRpcUrl);
          envUpdates[epochToTimeMapping[key]] = String(calculatedTime);
          console.log(`  ✓ ${epochToTimeMapping[key]}=${calculatedTime} (calculated)`);
        } catch (error) {
          console.log(`  ⚠ Failed to calculate ${epochToTimeMapping[key]}: ${error.message}`);
          console.log(`  You may need to set ${epochToTimeMapping[key]} manually`);
        }
      }
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

  const confirmed = await confirm('\nProceed with updating beacon and validator nodes?', true);
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
  const selected = getCurrentNetwork();
  if (!selected) {
    console.log('No network selected');
    await waitForEnter();
    return;
  }

  sectionHeader(`Manage Network Configuration: ${selected}`);
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
      const depositContract = await prompt(`CL Deposit Contract Address [${current.CL_DEPOSIT_CONTRACT_ADDRESS || '0x4242424242424242424242424242424242424242'}]: `);
      const depositChainId = await prompt(`CL Deposit Chain ID [${current.CL_DEPOSIT_CHAIN_ID || 84}]: `);
      const depositNetworkId = await prompt(`CL Deposit Network ID [${current.CL_DEPOSIT_NETWORK_ID || 84}]: `);
      const minGenesis = await prompt(`CL Min Genesis Validator Count [${current.CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT || 8}]: `);
      const depositBlock = await prompt(`CL Deposit Block [${current.CL_DEPOSIT_BLOCK || 0}]: `);
      const genesisStateUrl = await prompt(`CL Genesis State URL [${current.CL_GENESIS_STATE_URL || ''}]: `);
      const secondsPerSlot = await prompt(`CL Seconds Per Slot [${current.CL_SECONDS_PER_SLOT || 5}]: `);
      const slotsPerEpoch = await prompt(`CL Slots Per Epoch [${current.CL_SLOTS_PER_EPOCH || 16}]: `);
      const secondsPerEth1Block = await prompt(`CL Seconds Per Eth1 Block [${current.CL_SECONDS_PER_ETH1_BLOCK || 5}]: `);
      const lighthouseImage = await prompt(`Lighthouse Image [${current.LH_IMAGE || 'sigp/lighthouse:v7.0.1'}]: `);
      if (depositContract) updates.CL_DEPOSIT_CONTRACT_ADDRESS = depositContract;
      if (depositChainId) updates.CL_DEPOSIT_CHAIN_ID = String(parseInt(depositChainId, 10));
      if (depositNetworkId) updates.CL_DEPOSIT_NETWORK_ID = String(parseInt(depositNetworkId, 10));
      if (minGenesis) updates.CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT = String(parseInt(minGenesis, 10));
      if (depositBlock) updates.CL_DEPOSIT_BLOCK = String(parseInt(depositBlock, 10));
      if (genesisStateUrl !== '') updates.CL_GENESIS_STATE_URL = genesisStateUrl || null;
      if (secondsPerSlot) updates.CL_SECONDS_PER_SLOT = String(parseInt(secondsPerSlot, 10));
      if (slotsPerEpoch) updates.CL_SLOTS_PER_EPOCH = String(parseInt(slotsPerEpoch, 10));
      if (secondsPerEth1Block) updates.CL_SECONDS_PER_ETH1_BLOCK = String(parseInt(secondsPerEth1Block, 10));
      if (lighthouseImage) updates.LH_IMAGE = lighthouseImage;
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

  const confirmed = await confirm('\nApply these updates?', true);
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
  const selected = getCurrentNetwork();
  if (!selected) {
    console.log('No network selected');
    await waitForEnter();
    return;
  }

  sectionHeader(`Delete Network: ${selected}`);
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
