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
  buildCommonStartupScript,
} from '../lib/gcpHelpers.js';
import {DEFAULT_REMOTE_ENV} from '../config/defaultRemoteEnv.js';

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

export async function initPoa({context} = {}) {
  const effectiveContext = context || loadDeploymentContext();
  const cliqueInstance = await createGcpVm({
    ...buildVmOptions(effectiveContext, 'clique'),
    machineType: 'e2-medium',
    bootDiskSize: '30GB',
    startupScriptBuilder: (params) =>
      buildCliqueStartupScript({
        ...params,
        envOverrides: effectiveContext?.envOverrides?.clique || {},
      }),
    tcpPorts: CLIQUE_NODE_TCP_PORTS,
    udpPorts: CLIQUE_NODE_UDP_PORTS,
  });

  const cliqueIp = getInstanceExternalIp(cliqueInstance);
  if (!cliqueIp) {
    throw new Error('Unable to determine clique node external IP');
  }
  console.log(`[init-poa] Clique node External IP: ${cliqueIp}`);

  const cliqueEnode = await waitForCliqueEnode(cliqueIp);
  console.log(`[init-poa] Clique enode: ${cliqueEnode}`);
  return {cliqueIp, cliqueEnode};
}

const executedDirectly = process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
if (executedDirectly) {
  initPoa()
    .then(() => {
      console.log('[init-poa] Completed');
    })
    .catch((err) => {
      console.error('[init-poa] Failed:', err);
      process.exit(1);
    });
}
