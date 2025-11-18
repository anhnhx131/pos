#!/bin/bash
# Script to connect to an existing network
# This creates both execution node (geth) and beacon node (lighthouse)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Set ROOT_DIR before sourcing config.sh to ensure correct paths when running with sudo
export ROOT_DIR="${ROOT_DIR:-$SCRIPT_DIR}"
source "$SCRIPT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Connect to an existing network by creating execution and beacon nodes"
  echo ""
  echo "Options:"
  echo "  --el-bootnode <enode>        Execution layer bootnode (enode://...) (required)"
  echo "  --cl-bootnodes <enr,enr>     Consensus layer bootnodes (ENR format, comma-separated)"
  echo "  --network-id <id>            Network ID (default: 1 for mainnet)"
  echo "  --chain-id <id>              Chain ID (default: 1 for mainnet)"
  echo "  --genesis-file <path>        Path to custom genesis.json (optional, will auto-build if not provided)"
  echo "  --el-rpc-port <port>         Expose EL RPC port (default: 8545)"
  echo "  --el-authrpc-port <port>     Expose EL Auth RPC port (default: 8551)"
  echo "  --cl-http-port <port>        Expose CL HTTP port (default: 3500)"
  echo "  --validator-keystore <json>  Validator keystore JSON (optional)"
  echo "  --validator-password <pass>  Validator keystore password (optional)"
  exit 1
}

EL_BOOTNODE="enode://226ef2fb48ad84c9bb76a628fbe886ba7902222372698e0ba5999f740622f2a43d33f3ed47964d5651a25489b6d9579b4c36caf209ff33dc69b06fb57b5dffc2@54.254.232.133:30303"
CL_BOOTNODES="enr:-IS4QPOOGJE5V8GmhjshFUZ0pHWWWV008jgMGH3reH3HMtoEIR8UPrnl4OQO4xNSuwAtcgL6Omf4YPqi0zxMYO1GevUBgmlkgnY0gmlwhAoHAgKJc2VjcDI1NmsxoQOIhz10UYFO65iCNMMmcXHJQmk2FRNrqm0KoNtpBCicpoN1ZHCCIyg"
NETWORK_ID="84"
CHAIN_ID="84"
GENESIS_FILE=""
EL_RPC_PORT="8545"
EL_AUTHRPC_PORT="8551"
CL_HTTP_PORT="3500"
VALIDATOR_KEYSTORE=""
VALIDATOR_PASSWORD_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --el-bootnode)
      EL_BOOTNODE="$2"
      shift 2
      ;;
    --cl-bootnodes)
      CL_BOOTNODES="$2"
      shift 2
      ;;
    --network-id)
      NETWORK_ID="$2"
      shift 2
      ;;
    --chain-id)
      CHAIN_ID="$2"
      shift 2
      ;;
    --genesis-file)
      GENESIS_FILE="$2"
      shift 2
      ;;
    --el-rpc-port)
      EL_RPC_PORT="$2"
      shift 2
      ;;
    --el-authrpc-port)
      EL_AUTHRPC_PORT="$2"
      shift 2
      ;;
    --cl-http-port)
      CL_HTTP_PORT="$2"
      shift 2
      ;;
    --validator-keystore)
      VALIDATOR_KEYSTORE="$2"
      shift 2
      ;;
    --validator-password)
      VALIDATOR_PASSWORD_OVERRIDE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

if [ -z "$EL_BOOTNODE" ]; then
  log_error "Execution layer bootnode (--el-bootnode) is required"
  usage
fi

log_info "=========================================="
log_info "Connecting to Existing Network"
log_info "=========================================="
log_info "Configuration:"
log_info "  EL Bootnode: $EL_BOOTNODE"
log_info "  CL Bootnodes: ${CL_BOOTNODES:-none}"
log_info "  Network ID: $NETWORK_ID"
log_info "  Chain ID: $CHAIN_ID"
log_info "=========================================="

# Export network settings
export NETWORK_ID
export CHAIN_ID
# Set NETWORK based on chain ID for config building
if [ "$CHAIN_ID" = "84" ] && [ "$NETWORK_ID" = "84" ]; then
  export NETWORK="joc"
elif [ "$CHAIN_ID" = "1" ] && [ "$NETWORK_ID" = "1" ]; then
  export NETWORK="eth"
fi

# Step 1: Prepare genesis file (if needed)
# For mainnet (chain ID 1), genesis is not needed as it will sync from network
if [ "$CHAIN_ID" = "1" ] && [ "$NETWORK_ID" = "1" ]; then
  log_info "Mainnet detected - node will sync genesis from network"
  # Unset GENESIS_FILE so create-node.sh will skip initialization
  unset GENESIS_FILE
elif [ -n "$GENESIS_FILE" ] && [ -f "$GENESIS_FILE" ]; then
  log_info "Using custom genesis file: $GENESIS_FILE"
  export GENESIS_FILE="$GENESIS_FILE"
else
  # Auto-build genesis file if not provided
  log_info "No genesis file provided - building one automatically..."
  # Use node directory for genesis file
  ensure_node_directories
  DEFAULT_GENESIS_FILE="$NODE_GENESIS_FILE"
  
  # Determine network name for build-genesis.sh
  if [ "$CHAIN_ID" = "84" ] && [ "$NETWORK_ID" = "84" ]; then
    BUILD_NETWORK="joc"
  else
    BUILD_NETWORK="joc"  # Default to joc, can be overridden
  fi
  
  log_info "Building genesis.json for network: $BUILD_NETWORK (chain ID: $CHAIN_ID, network ID: $NETWORK_ID)"
  bash "$SCRIPT_DIR/modules/geth/build-genesis.sh" \
    --network "$BUILD_NETWORK" \
    --chain-id "$CHAIN_ID" \
    --network-id "$NETWORK_ID" \
    --output "$DEFAULT_GENESIS_FILE"
  
  export GENESIS_FILE="$DEFAULT_GENESIS_FILE"
  log_info "Genesis file created at: $GENESIS_FILE"
fi

# Step 2: Create execution node (geth)
log_info "Step 2: Creating execution node (geth)..."
# Ensure node directories exist (safe to call multiple times)
ensure_node_directories

bash "$SCRIPT_DIR/modules/geth/create-node.sh" \
  --bootnode "$EL_BOOTNODE" \
  --rpc-port "$EL_RPC_PORT" \
  --authrpc-port "$EL_AUTHRPC_PORT"

log_info "Execution node container: geth-node"

# Step 3: Build lighthouse config if needed
# For mainnet, we might need to use mainnet config
if [ "$CHAIN_ID" = "1" ] && [ "$NETWORK_ID" = "1" ]; then
  log_info "Step 3: Using mainnet configuration for Lighthouse..."
  # For mainnet, Lighthouse uses built-in mainnet config
  # We just need to ensure config directory exists
  mkdir -p "$NODE_CONFIG_DIR"
  if [ ! -f "$NODE_CONFIG_DIR/config.yaml" ]; then
    log_warn "config.yaml not found. Lighthouse will use built-in mainnet config."
    log_warn "If you need custom config, run: bash modules/lighthouse/build-config.sh --network eth"
  fi
else
  log_info "Step 3: Building Lighthouse config..."
  bash "$SCRIPT_DIR/modules/lighthouse/build-config.sh" \
    --network "${NETWORK:-joc}" \
    --chain-id "$CHAIN_ID" \
    --network-id "$NETWORK_ID" \
    --output "$NODE_CONFIG_DIR/config.yaml"
fi

# Step 4: Create beacon node (lighthouse)
log_info "Step 4: Creating beacon node (lighthouse)..."

BEACON_ARGS="--el-container geth-node --http-port $CL_HTTP_PORT"
[ -n "$CL_BOOTNODES" ] && BEACON_ARGS="$BEACON_ARGS --boot-nodes $CL_BOOTNODES"

bash "$SCRIPT_DIR/modules/lighthouse/create-beacon-node.sh" $BEACON_ARGS

log_info "Beacon node container: lighthouse-beacon"

# Step 5: Create validator client if keystore provided
if [ -n "$VALIDATOR_KEYSTORE" ]; then
  if [ -z "$VALIDATOR_PASSWORD_OVERRIDE" ]; then
    log_error "--validator-password is required when --validator-keystore is provided"
    exit 1
  fi
  log_info "Step 5: Creating validator client..."
  VALIDATOR_ARGS=(--beacon-container lighthouse-beacon --keystore "$VALIDATOR_KEYSTORE" --password "$VALIDATOR_PASSWORD_OVERRIDE")
  bash "$SCRIPT_DIR/modules/lighthouse/create-validator.sh" "${VALIDATOR_ARGS[@]}"
  log_info "Validator client container: lighthouse-validator"
else
  log_warn "Validator keystore not provided. Skipping validator client creation."
fi

log_info "=========================================="
log_info "Connection setup complete!"
log_info "=========================================="
log_info ""
log_info "Access points:"
log_info "  Execution Layer RPC: http://localhost:$EL_RPC_PORT"
log_info "  Execution Layer Auth RPC: http://localhost:$EL_AUTHRPC_PORT"
log_info "  Beacon API: http://localhost:$CL_HTTP_PORT"
log_info ""
log_info "Useful commands:"
log_info "  View EL logs: docker logs geth-node"
log_info "  View CL logs: docker logs lighthouse-beacon"
log_info "  Check EL sync: curl -X POST -H \"Content-Type: application/json\" --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_syncing\",\"params\":[],\"id\":1}' http://localhost:$EL_RPC_PORT"
log_info "  Check CL sync: curl http://localhost:$CL_HTTP_PORT/eth/v1/node/syncing"
log_info ""

