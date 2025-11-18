#!/bin/bash
# Create a Geth execution layer node

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Set ROOT_DIR if not already set (allows override from parent scripts)
export ROOT_DIR="${ROOT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$ROOT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --name <name>             Container name (default: geth-node)"
  echo "  --bootnode <enode>        Bootnode enode URL (default: from config)"
  echo "  --rpc-port <port>         Expose RPC port on host"
  echo "  --authrpc-port <port>     Expose Auth RPC port on host"
  exit 1
}

# Defaults
NODE_NAME=""
BOOTNODE="${GETH_BOOTNODE_ENODE}"
RPC_PORT=""
AUTHRPC_PORT=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --name)
      NODE_NAME="$2"
      shift 2
      ;;
    --bootnode)
      BOOTNODE="$2"
      shift 2
      ;;
    --rpc-port)
      RPC_PORT="$2"
      shift 2
      ;;
    --authrpc-port)
      AUTHRPC_PORT="$2"
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

# Set defaults
[ -z "$NODE_NAME" ] && NODE_NAME="geth-node"

log_info "Creating Geth Node"
log_info "  Name: $NODE_NAME"

# Create network if not exists
create_docker_network
ensure_node_directories

# Create node data directory
EL_DATA_DIR="$NODE_EL_DIR"
mkdir -p "$EL_DATA_DIR"

# Initialize node if not already initialized
if [ ! -d "$EL_DATA_DIR/geth" ]; then
  if [ -n "$GENESIS_FILE" ] && [ -f "$GENESIS_FILE" ]; then
    log_info "Initializing node with genesis..."
    docker run --rm \
      -v "$EL_DATA_DIR:/.ethereum" \
      -v "$GENESIS_FILE:/.genesis.json" \
      $GETH_IMAGE \
      --datadir /.ethereum init /.genesis.json
  else
    log_info "No genesis file provided - node will sync from network (mainnet mode)"
    # For mainnet, we can skip initialization and let geth sync from network
  fi
fi

# Stop and remove existing node if running
if docker ps -a --format '{{.Names}}' | grep -q "^${NODE_NAME}$"; then
  log_warn "Stopping existing node: $NODE_NAME"
  docker stop $NODE_NAME >/dev/null 2>&1 || true
  docker rm $NODE_NAME >/dev/null 2>&1 || true
fi

# Build docker run command
DOCKER_CMD="docker run -d --name $NODE_NAME --network $DOCKER_NETWORK_NAME"

# Add port mappings if specified
[ -n "$RPC_PORT" ] && DOCKER_CMD="$DOCKER_CMD -p ${RPC_PORT}:8545"
[ -n "$AUTHRPC_PORT" ] && DOCKER_CMD="$DOCKER_CMD -p ${AUTHRPC_PORT}:8551"

# Add volumes
DOCKER_CMD="$DOCKER_CMD -v $EL_DATA_DIR:/.ethereum -v $NODE_CONFIG_DIR:/node-config"

# Add geth command and arguments
DOCKER_CMD="$DOCKER_CMD $GETH_IMAGE"
DOCKER_CMD="$DOCKER_CMD --datadir=/.ethereum"
DOCKER_CMD="$DOCKER_CMD --networkid=$NETWORK_ID"
DOCKER_CMD="$DOCKER_CMD --http"
DOCKER_CMD="$DOCKER_CMD --http.addr=0.0.0.0"
DOCKER_CMD="$DOCKER_CMD --http.api=eth,net,web3,debug,trace,engine,admin"
DOCKER_CMD="$DOCKER_CMD --http.corsdomain=*"
DOCKER_CMD="$DOCKER_CMD --http.vhosts=*"
DOCKER_CMD="$DOCKER_CMD --authrpc.addr=0.0.0.0"
DOCKER_CMD="$DOCKER_CMD --authrpc.vhosts=*"
DOCKER_CMD="$DOCKER_CMD --authrpc.jwtsecret=/node-config/jwtsecret"
DOCKER_CMD="$DOCKER_CMD --syncmode=full"
DOCKER_CMD="$DOCKER_CMD --rpc.allow-unprotected-txs"
DOCKER_CMD="$DOCKER_CMD --verbosity=3"

# Add bootnode if specified
[ -n "$BOOTNODE" ] && DOCKER_CMD="$DOCKER_CMD --bootnodes=$BOOTNODE"

# Run node
log_info "Starting Geth node..."
eval $DOCKER_CMD

log_info "Geth node started successfully!"
log_info "Container: $NODE_NAME"
[ -n "$RPC_PORT" ] && log_info "RPC: http://localhost:${RPC_PORT}"
[ -n "$AUTHRPC_PORT" ] && log_info "Auth RPC: http://localhost:${AUTHRPC_PORT}"
log_info "Internal Auth RPC: http://${NODE_NAME}:8551"

log_info "Done!"

