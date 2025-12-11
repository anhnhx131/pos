#!/usr/bin/env node
import path from 'path';
import {fileURLToPath} from 'url';
import {
  loadDeploymentContext,
  buildVmOptions,
  createGcpVm,
  getInstanceExternalIp,
  buildEnvContent,
  buildCommonStartupScript,
} from '../lib/gcpHelpers.js';
import {DEFAULT_REMOTE_ENV} from '../config/defaultRemoteEnv.js';

const BLOCKSCOUT_TCP_PORTS = [22, 80, 4000];
const BLOCKSCOUT_UDP_PORTS = [];

function buildBlockscoutStartupScript({sshUser, sshKey, envOverrides = {}}) {
  const envContent = buildEnvContent({
    ...DEFAULT_REMOTE_ENV,
    ...envOverrides,
  });
  return buildCommonStartupScript({sshUser, sshKey, deployType: 'blockscout', envContent});
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

export async function createBlockscoutNode({elRpcUrl, networkId, networkName, context} = {}) {
  const effectiveElRpcUrl = elRpcUrl || process.env.EL_RPC_URL || getArgValue('--el-rpc-url');
  if (!effectiveElRpcUrl) {
    throw new Error('Missing EL RPC URL. Provide via EL_RPC_URL env or --el-rpc-url flag.');
  }
  const effectiveNetworkId = networkId || process.env.NETWORK_ID || getArgValue('--network-id') || 84;
  const effectiveNetworkName = networkName || process.env.NETWORK_NAME || getArgValue('--network-name') || 'POA Network';
  const effectiveContext = context || loadDeploymentContext();

  // Extract IP from EL RPC URL for public host if needed
  const elRpcHost = effectiveElRpcUrl.replace(/^https?:\/\//, '').split(':')[0];

  // Build env overrides for blockscout
  const envOverrides = {
    COMPOSE_FILE: 'blockscout.yml',
    BLOCKSCOUT_EL_RPC_URL: effectiveElRpcUrl,
    BLOCKSCOUT_TRACE_URL: effectiveElRpcUrl,
    BLOCKSCOUT_NETWORK_ID: String(effectiveNetworkId),
    BLOCKSCOUT_NETWORK_NAME: `'${effectiveNetworkName}'`,
    BLOCKSCOUT_PUBLIC_HOST: '\${NODE_IP}', // Will be replaced by startup script
    BLOCKSCOUT_PUBLIC_PROTOCOL: 'http',
    BLOCKSCOUT_VISUALIZE_API_HOST: 'http://\${NODE_IP}',
    BLOCKSCOUT_STATS_API_HOST: 'http://\${NODE_IP}',
    ...(effectiveContext?.envOverrides?.blockscout || {}),
  };

  const blockscoutInstance = await createGcpVm({
    ...buildVmOptions(effectiveContext, 'blockscout'),
    machineType: 'e2-medium',
    bootDiskSize: '50GB',
    startupScriptBuilder: (params) =>
      buildBlockscoutStartupScript({
        ...params,
        envOverrides,
      }),
    tcpPorts: BLOCKSCOUT_TCP_PORTS,
    udpPorts: BLOCKSCOUT_UDP_PORTS,
  });

  const blockscoutIp = getInstanceExternalIp(blockscoutInstance);
  if (blockscoutIp) {
    console.log(`[create-blockscout] Blockscout External IP: ${blockscoutIp}`);
  }
  console.log('[create-blockscout] Deployment initiated. Check startup logs on the VM for progress.');
  return {blockscoutIp: blockscoutIp || null};
}

const executedDirectly = process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
if (executedDirectly) {
  createBlockscoutNode()
    .then(() => {
      console.log('[create-blockscout] Completed');
    })
    .catch((err) => {
      console.error('[create-blockscout] Failed:', err);
      process.exit(1);
    });
}
