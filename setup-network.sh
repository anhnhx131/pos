#!/bin/bash
# Main orchestrator script to setup a complete PoS network

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Setup a complete Ethereum PoS network with multiple nodes"
  echo ""
  echo "Options:"
  echo "  --network <network>       Network name (joc, eth...) (default: joc)"
  echo "  --num-nodes <n>           Number of validator nodes (default: 3)"
  echo "  --enable-blockscout       Enable Blockscout explorer"
  echo "  --enable-dora             Enable Dora beacon chain explorer"
  echo "  --skip-deposit            Skip automatic deposit"
  echo "  --rpc-port <port>         Expose RPC on port (default: 8545)"
  echo ""
  echo "This script will:"
  echo "  1. Create Docker network"
  echo "  2. Start Geth bootnode"
  echo "  3. Start Lighthouse bootnodes (2)"
  echo "  4. Start N validator nodes (Geth + Lighthouse + Validator)"
  echo "  5. Optionally start explorers"
  echo "  6. Optionally make deposits"
  exit 1
}

NETWORK="${NETWORK:-joc}"
NUM_NODES=3
ENABLE_BLOCKSCOUT=false
ENABLE_DORA=false
SKIP_DEPOSIT=false
RPC_PORT=8545

while [[ $# -gt 0 ]]; do
  case $1 in
    --network)
      NETWORK="$2"
      shift 2
      ;;
    --num-nodes)
      NUM_NODES="$2"
      shift 2
      ;;
    --enable-blockscout)
      ENABLE_BLOCKSCOUT=true
      shift
      ;;
    --enable-dora)
      ENABLE_DORA=true
      shift
      ;;
    --skip-deposit)
      SKIP_DEPOSIT=true
      shift
      ;;
    --rpc-port)
      RPC_PORT="$2"
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

log_info "=========================================="
log_info "PoS Network Setup"
log_info "=========================================="
log_info "Configuration:"
log_info "  Network: $NETWORK"
log_info "  Number of nodes: $NUM_NODES"
log_info "  Blockscout: $ENABLE_BLOCKSCOUT"
log_info "  Dora: $ENABLE_DORA"
log_info "  Skip deposit: $SKIP_DEPOSIT"
log_info "  RPC Port: $RPC_PORT"
log_info "=========================================="

# Step 0: Build configurations
log_info "Step 0: Building configurations for network: $NETWORK"
log_info "Building Lighthouse config..."
build_lighthouse_config "$NETWORK" "$CONFIG_DIR/config.yaml"
log_info "Building Geth genesis..."
build_geth_genesis "$NETWORK" "$GENESIS_FILE"

# Step 1: Create network
log_info "Step 1: Creating Docker network..."
create_docker_network

# Step 2: Start Geth bootnode
log_info "Step 2: Starting Geth bootnode..."
bash "$SCRIPT_DIR/modules/geth/create-bootnode.sh"

# Step 3: Start Lighthouse bootnodes
log_info "Step 3: Starting Lighthouse bootnodes..."
bash "$SCRIPT_DIR/modules/lighthouse/create-bootnode.sh" 0
bash "$SCRIPT_DIR/modules/lighthouse/create-bootnode.sh" 1

# Wait for bootnodes to initialize
log_info "Waiting for bootnodes to initialize..."
sleep 5

# Step 4: Start validator nodes
log_info "Step 4: Starting validator nodes..."

# Predefined validator data (from config.sh)
MINER_NODES=(
    '{"public_key":"23081455D3FEaf17426176dfc5Ee7A3ce519aD33","private_key":"3c88fc7d33772dfa81e3c44347a3f9fc1df5946b70e3ba4f8a601e23e94d9072"}'
    '{"public_key":"d1d38fdc2669a694bf045b972a68654227143bd6","private_key":"f04e42bede52b46cf4c30b68eb56f96b87fcdae0d713861d72f9dfedaf0620aa"}'
    '{"public_key":"Cbba703129cC993b8c02Ce0AfB4Cd85E26ABa56c","private_key":"a4d13521428735961755d278f8d8f48e7cc35a14d07d29d8de8df9a7908bd590"}'
)

BEACON_VALIDATORS=(
    '{"crypto": {"kdf": {"function": "scrypt", "params": {"dklen": 32, "n": 262144, "r": 8, "p": 1, "salt": "ca31f176cbd4025e59f6212218db30964e4599d46a23cb066545988c4209d3bc"}, "message": ""}, "checksum": {"function": "sha256", "params": {}, "message": "975cabc6f73d30fc6e8a3de33d9e6138156f71f08616e60e20c048fd30a1cd7e"}, "cipher": {"function": "aes-128-ctr", "params": {"iv": "e3b135f4a2fcf7d36d1f420c80b527b0"}, "message": "db92545b28449f5c8fc77d5d005eb43ff0c35f1aa3113578edffe26285348244"}}, "description": "", "pubkey": "88c6de18d28e4abcecd66537dd86f0b440f14f1be806c70aa6bf0dd3cbd2ab2393d419dbdde063fbf6a850312d0609d9", "path": "m/12381/3600/0/0/0", "uuid": "72126f05-3d17-42f9-8557-69cd1d4fb2e9", "version": 4}'
    '{"crypto": {"kdf": {"function": "scrypt", "params": {"dklen": 32, "n": 262144, "r": 8, "p": 1, "salt": "d72c0ef760749dad872c46b60ba9ddf7b9dfe8c0d48dab51e9101d4493d44136"}, "message": ""}, "checksum": {"function": "sha256", "params": {}, "message": "ce581e1df4783e46e20cd43bfa4b848645498ef5a4b64712c4d9fb1b4d9d9bd5"}, "cipher": {"function": "aes-128-ctr", "params": {"iv": "aa83985a0361d7882a97b05c222433ba"}, "message": "57e3066c690bce055cd5c213f856c396955e8a60d22c3c6282d82cf8b78ab5c3"}}, "description": "", "pubkey": "a8bfcbc6f10233ba131eefaceb525460362c907c3866ea7e92f51c15f09112ad209aacb6124c0dd1724c409da7eb0901", "path": "m/12381/3600/1/0/0", "uuid": "c3bcabdf-85eb-4581-8069-6b725abd899b", "version": 4}'
    '{"crypto": {"kdf": {"function": "scrypt", "params": {"dklen": 32, "n": 262144, "r": 8, "p": 1, "salt": "9d3ea38a506b60150affd71b490e2692b92b44f97eddd49e016387e010433aa0"}, "message": ""}, "checksum": {"function": "sha256", "params": {}, "message": "8719561565ca401549ba3f9ce1fe4c634e239a6ee0783eb2fcf490b3f2e11b1a"}, "cipher": {"function": "aes-128-ctr", "params": {"iv": "2010b51509ce7b77928580061c792ab8"}, "message": "5ae66bda136d0de53453f69643cee9319c5bcb4e6631d6caeacfddaadb0484ab"}}, "description": "", "pubkey": "a036aa6f2c1cc478731679dbc7c5f6ec2df35e825083d9b02699f7468f6be57d2de9b2ecdc305afd435e3d89e03ed325", "path": "m/12381/3600/0/0/0", "uuid": "04a6dcd9-abdb-42ec-93eb-91c20c8876f8", "version": 4}'
)

for (( i=0; i<$NUM_NODES && i<${#MINER_NODES[@]}; i++ )); do
  log_info "Creating node $i..."
  
  EL_NODE_IP=$(get_next_el_ip $i)
  BEACON_NODE_IP=$(get_next_cl_ip $i)
  
  PRIVATE_KEY=$(echo ${MINER_NODES[$i]} | jq -r .private_key)
  PUBLIC_KEY=$(echo ${MINER_NODES[$i]} | jq -r .public_key)
  
  # Create Geth node
  GETH_ARGS="$i --ip $EL_NODE_IP --private-key $PRIVATE_KEY --public-key $PUBLIC_KEY"
  [ "$i" -eq 0 ] && GETH_ARGS="$GETH_ARGS --enable-mining --rpc-port $RPC_PORT"
  
  bash "$SCRIPT_DIR/modules/geth/create-node.sh" $GETH_ARGS
  
  # Create Beacon node
  BEACON_ARGS="$i --ip $BEACON_NODE_IP --el-ip $EL_NODE_IP"
  [ "$i" -eq 0 ] && BEACON_ARGS="$BEACON_ARGS --http-port 3500"
  
  bash "$SCRIPT_DIR/modules/lighthouse/create-beacon-node.sh" $BEACON_ARGS
  
  # Create Validator (if keystore available)
  if [ $i -lt ${#BEACON_VALIDATORS[@]} ]; then
    log_info "Creating validator $i..."
    
    # Write keystore to temp file
    KEYSTORE_FILE="/tmp/keystore-$i-$$.json"
    echo "${BEACON_VALIDATORS[$i]}" > "$KEYSTORE_FILE"
    
    bash "$SCRIPT_DIR/modules/lighthouse/create-validator.sh" $i \
      --beacon-ip $BEACON_NODE_IP \
      --keystore-file "$KEYSTORE_FILE"
    
    rm -f "$KEYSTORE_FILE"
  fi
  
  log_info "Node $i created successfully"
done

# Wait for nodes to sync
log_info "Waiting for nodes to initialize..."
sleep 10

# Step 5: Make deposits (if not skipped)
if [ "$SKIP_DEPOSIT" = false ]; then
  log_info "Step 5: Making validator deposits..."
  bash "$SCRIPT_DIR/modules/deposit/batch-deposit.sh"
else
  log_info "Step 5: Skipping deposits (--skip-deposit specified)"
fi

# Step 6: Start explorers
if [ "$ENABLE_DORA" = true ]; then
  log_info "Step 6a: Starting Dora beacon chain explorer..."
  bash "$SCRIPT_DIR/modules/dora/start.sh"
fi

if [ "$ENABLE_BLOCKSCOUT" = true ]; then
  log_info "Step 6b: Starting Blockscout explorer..."
  bash "$SCRIPT_DIR/modules/blockscout/start.sh"
fi

log_info "=========================================="
log_info "Network setup complete!"
log_info "=========================================="
log_info ""
log_info "Access points:"
log_info "  Geth RPC: http://localhost:$RPC_PORT"
log_info "  Beacon API: http://localhost:3500"
[ "$ENABLE_DORA" = true ] && log_info "  Dora Explorer: http://localhost:$DORA_PORT"
[ "$ENABLE_BLOCKSCOUT" = true ] && log_info "  Blockscout: http://localhost:$BLOCKSCOUT_PORT"
log_info ""
log_info "Useful commands:"
log_info "  List Geth nodes: bash modules/geth/list-nodes.sh"
log_info "  List Lighthouse nodes: bash modules/lighthouse/list-nodes.sh"
log_info "  View logs: docker logs <container-name>"
log_info ""

