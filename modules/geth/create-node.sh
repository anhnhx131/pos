#!/bin/bash
# Create a Geth execution layer node

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 <node_index> [options]"
  echo ""
  echo "Options:"
  echo "  --ip <ip>                 Node IP address (default: auto-assign based on index)"
  echo "  --name <name>             Container name (default: geth-node-<index>)"
  echo "  --private-key <key>       Private key for mining/account"
  echo "  --public-key <key>        Public key/address for mining"
  echo "  --bootnode <enode>        Bootnode enode URL (default: from config)"
  echo "  --enable-mining           Enable mining on this node"
  echo "  --rpc-port <port>         Expose RPC port on host"
  echo "  --authrpc-port <port>     Expose Auth RPC port on host"
  exit 1
}

# Defaults
NODE_INDEX=""
NODE_IP=""
NODE_NAME=""
PRIVATE_KEY=""
PUBLIC_KEY=""
BOOTNODE="${GETH_BOOTNODE_ENODE}"
ENABLE_MINING=false
RPC_PORT=""
AUTHRPC_PORT=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --ip)
      NODE_IP="$2"
      shift 2
      ;;
    --name)
      NODE_NAME="$2"
      shift 2
      ;;
    --private-key)
      PRIVATE_KEY="$2"
      shift 2
      ;;
    --public-key)
      PUBLIC_KEY="$2"
      shift 2
      ;;
    --bootnode)
      BOOTNODE="$2"
      shift 2
      ;;
    --enable-mining)
      ENABLE_MINING=true
      shift
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
      if [ -z "$NODE_INDEX" ]; then
        NODE_INDEX="$1"
      else
        echo "Unknown option: $1"
        usage
      fi
      shift
      ;;
  esac
done

# Validate required arguments
if [ -z "$NODE_INDEX" ]; then
  log_error "Node index is required"
  usage
fi

# Set defaults based on node index
[ -z "$NODE_IP" ] && NODE_IP=$(get_next_el_ip $NODE_INDEX)
[ -z "$NODE_NAME" ] && NODE_NAME="geth-node-${NODE_INDEX}"

log_info "Creating Geth Node"
log_info "  Index: $NODE_INDEX"
log_info "  Name: $NODE_NAME"
log_info "  IP: $NODE_IP"
log_info "  Mining: $ENABLE_MINING"

# Create network if not exists
create_docker_network

# Create node data directory
NODE_DIR="${EL_DIR}/geth/${NODE_NAME}"
mkdir -p "$NODE_DIR"
echo "$JWT_SECRET" > "$NODE_DIR/jwtsecret"

# Import private key if provided
if [ -n "$PRIVATE_KEY" ] && [ -n "$PUBLIC_KEY" ]; then
  log_info "Importing account with private key..."
  echo "$PRIVATE_KEY" > "$NODE_DIR/private.key"
  echo "password" > "$NODE_DIR/password.txt"
  
  docker run --rm \
    -v "$NODE_DIR:/.ethereum" \
    $GETH_IMAGE \
    account import --datadir /.ethereum --password /.ethereum/password.txt /.ethereum/private.key
fi

# Initialize node if not already initialized
if [ ! -d "$NODE_DIR/geth" ]; then
  if [ -n "$GENESIS_FILE" ] && [ -f "$GENESIS_FILE" ]; then
    log_info "Initializing node with genesis..."
    docker run --rm \
      -v "$NODE_DIR:/.ethereum" \
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
DOCKER_CMD="docker run -d --name $NODE_NAME --network $DOCKER_NETWORK_NAME --ip $NODE_IP"

# Add port mappings if specified
[ -n "$RPC_PORT" ] && DOCKER_CMD="$DOCKER_CMD -p ${RPC_PORT}:8545"
[ -n "$AUTHRPC_PORT" ] && DOCKER_CMD="$DOCKER_CMD -p ${AUTHRPC_PORT}:8551"

# Add volumes
DOCKER_CMD="$DOCKER_CMD -v $NODE_DIR:/.ethereum"

# Add geth command and arguments
DOCKER_CMD="$DOCKER_CMD $GETH_IMAGE"
DOCKER_CMD="$DOCKER_CMD --datadir=/.ethereum"
DOCKER_CMD="$DOCKER_CMD --networkid=$NETWORK_ID"
DOCKER_CMD="$DOCKER_CMD --nat=extip:$NODE_IP"
DOCKER_CMD="$DOCKER_CMD --http"
DOCKER_CMD="$DOCKER_CMD --http.addr=0.0.0.0"
DOCKER_CMD="$DOCKER_CMD --http.api=eth,net,web3,debug,trace,engine,admin"
DOCKER_CMD="$DOCKER_CMD --http.corsdomain=*"
DOCKER_CMD="$DOCKER_CMD --http.vhosts=*"
DOCKER_CMD="$DOCKER_CMD --authrpc.addr=0.0.0.0"
DOCKER_CMD="$DOCKER_CMD --authrpc.vhosts=*"
DOCKER_CMD="$DOCKER_CMD --authrpc.jwtsecret=/.ethereum/jwtsecret"
DOCKER_CMD="$DOCKER_CMD --syncmode=full"
DOCKER_CMD="$DOCKER_CMD --rpc.allow-unprotected-txs"
DOCKER_CMD="$DOCKER_CMD --verbosity=3"

# Add bootnode if specified
[ -n "$BOOTNODE" ] && DOCKER_CMD="$DOCKER_CMD --bootnodes=$BOOTNODE"

# Add mining options if enabled
if [ "$ENABLE_MINING" = true ] && [ -n "$PUBLIC_KEY" ]; then
  DOCKER_CMD="$DOCKER_CMD --unlock=$PUBLIC_KEY"
  DOCKER_CMD="$DOCKER_CMD --miner.etherbase=$PUBLIC_KEY"
  DOCKER_CMD="$DOCKER_CMD --mine"
  DOCKER_CMD="$DOCKER_CMD --password=/.ethereum/password.txt"
  DOCKER_CMD="$DOCKER_CMD --allow-insecure-unlock"
fi

# Run node
log_info "Starting Geth node..."
eval $DOCKER_CMD

log_info "Geth node started successfully!"
log_info "Container: $NODE_NAME"
log_info "IP: $NODE_IP"
[ -n "$RPC_PORT" ] && log_info "RPC: http://localhost:${RPC_PORT}"
[ -n "$AUTHRPC_PORT" ] && log_info "Auth RPC: http://localhost:${AUTHRPC_PORT}"

log_info "Done!"

