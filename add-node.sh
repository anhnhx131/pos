#!/bin/bash
# Add a new node to an existing PoS network

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 <node_index> [options]"
  echo ""
  echo "Add a new validator node to existing network"
  echo ""
  echo "Options:"
  echo "  --network <network>       Network name (joc, eth...) (default: joc)"
  echo "  --el-ip <ip>              Execution layer IP"
  echo "  --cl-ip <ip>              Consensus layer IP"
  echo "  --private-key <key>       Geth private key"
  echo "  --public-key <key>        Geth public key/address"
  echo "  --keystore <json>         Validator keystore JSON"
  echo "  --keystore-file <path>    Validator keystore file"
  echo "  --enable-mining           Enable mining on Geth node"
  echo "  --rpc-port <port>         Expose RPC port"
  echo "  --beacon-port <port>      Expose beacon HTTP port"
  exit 1
}

NODE_INDEX=""
NETWORK="${NETWORK:-joc}"
EL_IP=""
CL_IP=""
PRIVATE_KEY=""
PUBLIC_KEY=""
KEYSTORE=""
KEYSTORE_FILE=""
ENABLE_MINING=false
RPC_PORT=""
BEACON_PORT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --network)
      NETWORK="$2"
      shift 2
      ;;
    --el-ip)
      EL_IP="$2"
      shift 2
      ;;
    --cl-ip)
      CL_IP="$2"
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
    --keystore)
      KEYSTORE="$2"
      shift 2
      ;;
    --keystore-file)
      KEYSTORE_FILE="$2"
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
    --beacon-port)
      BEACON_PORT="$2"
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

if [ -z "$NODE_INDEX" ]; then
  log_error "Node index is required"
  usage
fi

# Set default IPs if not provided
[ -z "$EL_IP" ] && EL_IP=$(get_next_el_ip $NODE_INDEX)
[ -z "$CL_IP" ] && CL_IP=$(get_next_cl_ip $NODE_INDEX)

log_info "=========================================="
log_info "Adding New Node to Network"
log_info "=========================================="
log_info "  Network: $NETWORK"
log_info "  Index: $NODE_INDEX"
log_info "  EL IP: $EL_IP"
log_info "  CL IP: $CL_IP"
log_info "  Mining: $ENABLE_MINING"
log_info "=========================================="

# Build Lighthouse config if not exists or network changed
if [ ! -f "$CONFIG_DIR/config.yaml" ] || [ "$(grep -c "CONFIG_NAME: '$NETWORK'" "$CONFIG_DIR/config.yaml" 2>/dev/null || echo 0)" -eq 0 ]; then
  log_info "Building Lighthouse config for network: $NETWORK"
  build_lighthouse_config "$NETWORK" "$CONFIG_DIR/config.yaml"
fi

# Build Geth genesis if not exists or network changed
# Get chain ID from network preset if not set
NETWORK_CHAIN_ID="${CHAIN_ID:-$([ "$NETWORK" = "joc" ] && echo 84 || echo 1)}"
if [ ! -f "$GENESIS_FILE" ] || [ "$(grep -c "\"chainId\": $NETWORK_CHAIN_ID" "$GENESIS_FILE" 2>/dev/null || echo 0)" -eq 0 ]; then
  log_info "Building Geth genesis for network: $NETWORK"
  build_geth_genesis "$NETWORK" "$GENESIS_FILE"
fi

# Create Geth node
log_info "Creating Geth node..."
GETH_ARGS="$NODE_INDEX --ip $EL_IP"
[ -n "$PRIVATE_KEY" ] && GETH_ARGS="$GETH_ARGS --private-key $PRIVATE_KEY"
[ -n "$PUBLIC_KEY" ] && GETH_ARGS="$GETH_ARGS --public-key $PUBLIC_KEY"
[ "$ENABLE_MINING" = true ] && GETH_ARGS="$GETH_ARGS --enable-mining"
[ -n "$RPC_PORT" ] && GETH_ARGS="$GETH_ARGS --rpc-port $RPC_PORT"

bash "$SCRIPT_DIR/modules/geth/create-node.sh" $GETH_ARGS

# Create Beacon node
log_info "Creating Beacon node..."
BEACON_ARGS="$NODE_INDEX --ip $CL_IP --el-ip $EL_IP"
[ -n "$BEACON_PORT" ] && BEACON_ARGS="$BEACON_ARGS --http-port $BEACON_PORT"

bash "$SCRIPT_DIR/modules/lighthouse/create-beacon-node.sh" $BEACON_ARGS

# Create Validator (if keystore provided)
if [ -n "$KEYSTORE" ] || [ -n "$KEYSTORE_FILE" ]; then
  log_info "Creating Validator..."
  
  VALIDATOR_ARGS="$NODE_INDEX --beacon-ip $CL_IP"
  [ -n "$KEYSTORE" ] && VALIDATOR_ARGS="$VALIDATOR_ARGS --keystore $KEYSTORE"
  [ -n "$KEYSTORE_FILE" ] && VALIDATOR_ARGS="$VALIDATOR_ARGS --keystore-file $KEYSTORE_FILE"
  
  bash "$SCRIPT_DIR/modules/lighthouse/create-validator.sh" $VALIDATOR_ARGS
fi

log_info "=========================================="
log_info "Node added successfully!"
log_info "=========================================="
log_info ""
log_info "Containers created:"
log_info "  Geth: geth-node-$NODE_INDEX"
log_info "  Beacon: lighthouse-beacon-$NODE_INDEX"
[ -n "$KEYSTORE" ] || [ -n "$KEYSTORE_FILE" ] && log_info "  Validator: lighthouse-validator-$NODE_INDEX"
log_info ""

