#!/usr/bin/env node
import fs from 'fs';
import SSH2Promise from 'ssh2-promise';
import {loadDeploymentContext} from './gcpHelpers.js';

/**
 * Build SSH config from context and IP
 */
export function buildSshConfig(host, context) {
  const keyMaterial = fs.readFileSync(context.sshPrivateKeyPath, 'utf8');
  return {
    host,
    username: context.sshUser,
    privateKey: keyMaterial,
  };
}

/**
 * Create SSH connection wrapper
 */
export async function withSshConnection(sshConfig, fn) {
  const ssh = new SSH2Promise(sshConfig);
  await ssh.connect();
  try {
    return await fn(ssh);
  } finally {
    await ssh.close();
  }
}

/**
 * Parse .env file content into an object
 */
export function parseEnvFile(content) {
  const env = {};
  const lines = content.split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const equalIndex = trimmed.indexOf('=');
    if (equalIndex === -1) continue;
    const key = trimmed.slice(0, equalIndex).trim();
    const value = trimmed.slice(equalIndex + 1).trim();
    env[key] = value;
  }
  return env;
}

/**
 * Format env value for .env file
 */
function formatEnvValue(value) {
  if (value === undefined || value === null) {
    return '';
  }
  const str = String(value);
  const alreadyQuoted = /^(['"]).*\1$/.test(str);
  if (alreadyQuoted) {
    return str;
  }

  const safePattern = /^[A-Za-z0-9_./:-]+$/;
  if (safePattern.test(str)) {
    return str;
  }

  const hasSingle = str.includes("'");
  const hasDouble = str.includes('"');

  if (!hasSingle) {
    return `'${str}'`;
  }
  if (!hasDouble) {
    return `"${str}"`;
  }

  const escaped = str.replace(/"/g, '\\"');
  return `"${escaped}"`;
}

/**
 * Convert env object back to .env file format
 */
export function envObjectToString(env) {
  return Object.entries(env)
    .map(([key, value]) => `${key}=${formatEnvValue(value)}`)
    .join('\n')
    .concat('\n');
}

/**
 * Read .env file from remote VM
 */
export async function readRemoteEnvFile(ssh, envPath) {
  try {
    const content = await ssh.exec(`sudo cat ${envPath} 2>/dev/null || echo ""`);
    return content.trim();
  } catch {
    return '';
  }
}

/**
 * Write .env file to remote VM
 */
export async function writeRemoteEnvFile(ssh, envPath, content) {
  const marker = `EOF_${Date.now()}_${Math.random().toString(36).slice(2)}`;
  const script = `cat <<'${marker}' > ${envPath}
${content}
${marker}
chmod 644 ${envPath}
`;
  const wrapperMarker = `${marker}_SCRIPT`;
  const command = `sudo /bin/bash <<'${wrapperMarker}'
${script}
${wrapperMarker}`;
  await ssh.exec(command);
}

/**
 * Update bootnode: update .env.bootnode, git pull, restart
 */
export async function updateBootnode(sshConfig, nodeInfo, envUpdates) {
  const {name, ip} = nodeInfo;
  console.log(`\n[updateBootnode] Updating ${name} at ${ip}...`);

  return withSshConnection(sshConfig, async (ssh) => {
    const envPath = '/data/pos/.env.bootnode';

    // 1. Update .env file
    console.log(`[updateBootnode] Reading current .env file...`);
    let currentEnvContent = await readRemoteEnvFile(ssh, envPath);
    if (!currentEnvContent) {
      currentEnvContent = await readRemoteEnvFile(ssh, '/data/pos/default.env') || '';
    }

    const currentEnv = parseEnvFile(currentEnvContent);
    const updatedEnv = {...currentEnv, ...envUpdates};

    // Preserve NODE_IP
    if (currentEnv.NODE_IP) {
      updatedEnv.NODE_IP = currentEnv.NODE_IP;
    }

    console.log(`[updateBootnode] Writing updated .env file...`);
    await writeRemoteEnvFile(ssh, envPath, envObjectToString(updatedEnv));

    // 2. Git pull latest code
    console.log(`[updateBootnode] Pulling latest code...`);
    await ssh.exec('cd /data/pos && sudo git pull origin eth-docker 2>&1 || sudo git pull 2>&1');

    // 3. Stop current services
    console.log(`[updateBootnode] Stopping current services...`);
    await ssh.exec('cd /data/pos && sudo ./start.sh down 2>&1 || true');
    await new Promise((resolve) => setTimeout(resolve, 3000));

    // 4. Start bootnode only
    console.log(`[updateBootnode] Starting bootnode...`);
    await ssh.exec('cd /data/pos && sudo ./start.sh bootnode .env.bootnode 2>&1');

    console.log(`[updateBootnode] ✓ Completed`);
  });
}

/**
 * Update beacon: update .env.beacon, git pull, restart
 */
export async function updateBeacon(sshConfig, nodeInfo, envUpdates) {
  const {name, ip} = nodeInfo;
  console.log(`\n[updateBeacon] Updating ${name} at ${ip}...`);

  return withSshConnection(sshConfig, async (ssh) => {
    const envPath = '/data/pos/.env.beacon';

    // 1. Update .env file
    console.log(`[updateBeacon] Reading current .env file...`);
    let currentEnvContent = await readRemoteEnvFile(ssh, envPath);
    if (!currentEnvContent) {
      currentEnvContent = await readRemoteEnvFile(ssh, '/data/pos/default.env') || '';
    }

    const currentEnv = parseEnvFile(currentEnvContent);
    const updatedEnv = {...currentEnv, ...envUpdates};

    // Preserve NODE_IP
    if (currentEnv.NODE_IP) {
      updatedEnv.NODE_IP = currentEnv.NODE_IP;
    }

    console.log(`[updateBeacon] Writing updated .env file...`);
    await writeRemoteEnvFile(ssh, envPath, envObjectToString(updatedEnv));

    // 2. Git pull latest code
    console.log(`[updateBeacon] Pulling latest code...`);
    await ssh.exec('cd /data/pos && sudo git pull origin eth-docker 2>&1 || sudo git pull 2>&1');

    // 3. Stop current services
    console.log(`[updateBeacon] Stopping current services...`);
    await ssh.exec('cd /data/pos && sudo ./start.sh down 2>&1 || true');
    await new Promise((resolve) => setTimeout(resolve, 3000));

    // 4. Start beacon stack
    console.log(`[updateBeacon] Starting beacon stack...`);
    await ssh.exec('cd /data/pos && sudo ./start.sh beacon .env.beacon 2>&1');

    console.log(`[updateBeacon] ✓ Completed`);
  });
}

/**
 * Update beacon-vc node: update .env.beacon, git pull, restart
 */
export async function updateBeaconVc(sshConfig, nodeInfo, envUpdates) {
  const {name, ip} = nodeInfo;
  console.log(`\n[updateBeaconVc] Updating ${name} at ${ip}...`);

  return withSshConnection(sshConfig, async (ssh) => {
    const envPath = '/data/pos/.env.beacon';

    // 1. Update .env file
    console.log(`[updateBeaconVc] Reading current .env file...`);
    let currentEnvContent = await readRemoteEnvFile(ssh, envPath);
    if (!currentEnvContent) {
      currentEnvContent = await readRemoteEnvFile(ssh, '/data/pos/default.env') || '';
    }

    const currentEnv = parseEnvFile(currentEnvContent);
    const updatedEnv = {...currentEnv, ...envUpdates};

    // Preserve NODE_IP
    if (currentEnv.NODE_IP) {
      updatedEnv.NODE_IP = currentEnv.NODE_IP;
    }

    console.log(`[updateBeaconVc] Writing updated .env file...`);
    await writeRemoteEnvFile(ssh, envPath, envObjectToString(updatedEnv));

    // 2. Git pull latest code
    console.log(`[updateBeaconVc] Pulling latest code...`);
    await ssh.exec('cd /data/pos && sudo git pull origin eth-docker 2>&1 || sudo git pull 2>&1');

    // 3. Stop current services
    console.log(`[updateBeaconVc] Stopping current services...`);
    await ssh.exec('cd /data/pos && sudo ./start.sh down 2>&1 || true');
    await new Promise((resolve) => setTimeout(resolve, 3000));

    // 4. Start beacon-vc
    console.log(`[updateBeaconVc] Starting beacon-vc...`);
    await ssh.exec('cd /data/pos && sudo ./start.sh beacon-vc .env.beacon 2>&1');

    console.log(`[updateBeaconVc] ✓ Completed`);
  });
}

/**
 * Update clique/POA node: update .env.clique, git pull, restart
 */
export async function updateClique(sshConfig, nodeInfo, envUpdates) {
  const {name, ip} = nodeInfo;
  console.log(`\n[updateClique] Updating ${name} at ${ip}...`);

  return withSshConnection(sshConfig, async (ssh) => {
    const envPath = '/data/pos/.env.clique';

    // 1. Update .env file
    console.log(`[updateClique] Reading current .env file...`);
    let currentEnvContent = await readRemoteEnvFile(ssh, envPath);
    if (!currentEnvContent) {
      currentEnvContent = await readRemoteEnvFile(ssh, '/data/pos/default.env') || '';
    }

    const currentEnv = parseEnvFile(currentEnvContent);
    const updatedEnv = {...currentEnv, ...envUpdates};

    // Preserve NODE_IP
    if (currentEnv.NODE_IP) {
      updatedEnv.NODE_IP = currentEnv.NODE_IP;
    }

    console.log(`[updateClique] Writing updated .env file...`);
    await writeRemoteEnvFile(ssh, envPath, envObjectToString(updatedEnv));

    // 2. Git pull latest code
    console.log(`[updateClique] Pulling latest code...`);
    await ssh.exec('cd /data/pos && sudo git pull origin eth-docker 2>&1 || sudo git pull 2>&1');

    // 3. Stop current services
    console.log(`[updateClique] Stopping current services...`);
    await ssh.exec('cd /data/pos && sudo ./start.sh down 2>&1 || true');
    await new Promise((resolve) => setTimeout(resolve, 3000));

    // 4. Start clique
    console.log(`[updateClique] Starting clique...`);
    await ssh.exec('cd /data/pos && sudo ./start.sh clique .env.clique 2>&1');

    console.log(`[updateClique] ✓ Completed`);
  });
}

/**
 * Update blockscout: update .env.joc, git pull, restart
 */
export async function updateBlockscout(sshConfig, nodeInfo, envUpdates) {
  const {name, ip} = nodeInfo;
  console.log(`\n[updateBlockscout] Updating ${name} at ${ip}...`);

  return withSshConnection(sshConfig, async (ssh) => {
    const envPath = '/data/pos/.env.joc';

    // 1. Update .env file
    console.log(`[updateBlockscout] Reading current .env file...`);
    let currentEnvContent = await readRemoteEnvFile(ssh, envPath);
    if (!currentEnvContent) {
      currentEnvContent = await readRemoteEnvFile(ssh, '/data/pos/default.env') || '';
    }

    const currentEnv = parseEnvFile(currentEnvContent);
    const updatedEnv = {...currentEnv, ...envUpdates};

    // Preserve NODE_IP
    if (currentEnv.NODE_IP) {
      updatedEnv.NODE_IP = currentEnv.NODE_IP;
    }

    // Replace NODE_IP placeholder if present in any value
    const nodeIp = currentEnv.NODE_IP || ip;
    Object.keys(updatedEnv).forEach(key => {
      if (typeof updatedEnv[key] === 'string' && updatedEnv[key].includes('${NODE_IP}')) {
        updatedEnv[key] = updatedEnv[key].replace(/\${NODE_IP}/g, nodeIp);
      }
    });

    console.log(`[updateBlockscout] Writing updated .env file...`);
    await writeRemoteEnvFile(ssh, envPath, envObjectToString(updatedEnv));

    // 2. Git pull latest code
    console.log(`[updateBlockscout] Pulling latest code...`);
    await ssh.exec('cd /data/pos && sudo git pull origin eth-docker 2>&1 || sudo git pull 2>&1');

    // 3. Stop current services
    console.log(`[updateBlockscout] Stopping current services...`);
    await ssh.exec('cd /data/pos && sudo ./start.sh down 2>&1 || true');
    await new Promise((resolve) => setTimeout(resolve, 3000));

    // 4. Start blockscout
    console.log(`[updateBlockscout] Starting blockscout...`);
    await ssh.exec('cd /data/pos && sudo ./start.sh blockscout .env.joc 2>&1');

    console.log(`[updateBlockscout] ✓ Completed`);
  });
}
