#!/bin/bash
# Shared configuration library for PoS network

# Network Configuration
export NETWORK="${NETWORK:-joc}"
export DOCKER_NETWORK_NAME="${DOCKER_NETWORK_NAME:-pos-network}"
export SUBNET="${SUBNET:-10.7.0.0/16}"
export NETWORK_ID="${NETWORK_ID:-84}"
export CHAIN_ID="${CHAIN_ID:-84}"

# JWT Secret for Execution/Consensus layer communication
export JWT_SECRET="${JWT_SECRET:-0xfad2709d0bb03bf0e8ba3c99bea194575d3e98863133d1af638ed056d1d59345}"

# Geth Configuration
export GETH_IMAGE="${GETH_IMAGE:-ethereum/client-go:v1.11.5}"
export GETH_BOOTNODE_KEY="${GETH_BOOTNODE_KEY:-31640af736ec4dfef9d776189b3ca4e6d7732d853b815ece7408c9d3c4e10433}"
export GETH_BOOTNODE_IP="${GETH_BOOTNODE_IP:-10.7.1.4}"
export GETH_BOOTNODE_PORT="${GETH_BOOTNODE_PORT:-30303}"
export GETH_BOOTNODE_ENODE="${GETH_BOOTNODE_ENODE:-enode://0c284ba5ce93c5879aa2f0f6132fe19e0278d32b38c4eef8b3da8e3bdba743e02732bf542e5cb282b857dc2ae278cac5c383fc37d66b014f1ae1e183045a41ea@${GETH_BOOTNODE_IP}:${GETH_BOOTNODE_PORT}}"

# Lighthouse Configuration
export LIGHTHOUSE_IMAGE="${LIGHTHOUSE_IMAGE:-sigp/lighthouse:v7.0.1}"
export VALIDATOR_PASSWORD="${VALIDATOR_PASSWORD:-password123456}"
export VALIDATOR_API_TOKEN="${VALIDATOR_API_TOKEN:-R6YhbDO6gKjNMydtZHcaCovFbQ0izq5Hk}"
export DEPOSIT_CONTRACT_BLOCK="${DEPOSIT_CONTRACT_BLOCK:-0}"

# Lighthouse Bootnodes
export LIGHTHOUSE_BOOTNODE_0_IP="${LIGHTHOUSE_BOOTNODE_0_IP:-10.7.2.2}"
export LIGHTHOUSE_BOOTNODE_1_IP="${LIGHTHOUSE_BOOTNODE_1_IP:-10.7.2.3}"
export LIGHTHOUSE_BOOTNODES="${LIGHTHOUSE_BOOTNODES:-enr:-IS4QPOOGJE5V8GmhjshFUZ0pHWWWV008jgMGH3reH3HMtoEIR8UPrnl4OQO4xNSuwAtcgL6Omf4YPqi0zxMYO1GevUBgmlkgnY0gmlwhAoHAgKJc2VjcDI1NmsxoQOIhz10UYFO65iCNMMmcXHJQmk2FRNrqm0KoNtpBCicpoN1ZHCCIyg,enr:-IS4QATvRDQtMnslfe2DDfQ9au3gvF0oD9yrUswhLMWycafWPLOU9ZjXG0L0m9RJq-7V3lFhKXm9nVslPfizMgvfQZsBgmlkgnY0gmlwhAoHAgOJc2VjcDI1NmsxoQLh78RCFhcrgZ5tKgayyL9TTVXnK8mIlzBZoWiYQqdlUoN1ZHCCIyg}"

# Paths
export ROOT_DIR="${ROOT_DIR:-$(pwd)}"
export EL_DIR="${ROOT_DIR}/el"
export CL_DIR="${ROOT_DIR}/cl"
export CONFIG_DIR="${CL_DIR}/config"
export GENESIS_FILE="${EL_DIR}/geth/genesis.json"

# Default Node Configuration
export DEFAULT_MINER_ACCOUNT="${DEFAULT_MINER_ACCOUNT:-0x23081455D3FEaf17426176dfc5Ee7A3ce519aD33}"
export DEFAULT_FEE_RECIPIENT="${DEFAULT_FEE_RECIPIENT:-0x23081455D3FEaf17426176dfc5Ee7A3ce519aD33}"

# Blockscout Configuration
export BLOCKSCOUT_PORT="${BLOCKSCOUT_PORT:-9000}"
export BLOCKSCOUT_DOCKER_USERNAME="${BLOCKSCOUT_DOCKER_USERNAME:-bccloud}"
export BLOCKSCOUT_DOCKER_PASSWORD="${BLOCKSCOUT_DOCKER_PASSWORD:-bell*deek5cell8PSUF}"

# Dora Configuration
export DORA_PORT="${DORA_PORT:-8080}"
export DORA_IMAGE="${DORA_IMAGE:-pk910/dora-the-explorer:v1.17.0}"

# Helper Functions
function create_docker_network() {
  if ! docker network inspect $DOCKER_NETWORK_NAME >/dev/null 2>&1; then
    echo "Creating Docker network: $DOCKER_NETWORK_NAME with subnet $SUBNET"
    docker network create $DOCKER_NETWORK_NAME --driver bridge --subnet $SUBNET
  else
    echo "Docker network $DOCKER_NETWORK_NAME already exists"
  fi
}

function get_next_el_ip() {
  local index=$1
  echo "10.7.1.$((index+10))"
}

function get_next_cl_ip() {
  local index=$1
  echo "10.7.2.$((index+10))"
}

function get_next_validator_ip() {
  local index=$1
  echo "10.7.3.$((index+10))"
}

function wait_for_service() {
  local host=$1
  local port=$2
  local timeout=${3:-30}
  
  echo "Waiting for service at $host:$port (timeout: ${timeout}s)..."
  for i in $(seq 1 $timeout); do
    if timeout 1 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
      echo "Service is ready!"
      return 0
    fi
    sleep 1
  done
  echo "Timeout waiting for service"
  return 1
}

function generate_jwt_secret() {
  openssl rand -hex 32
}

function build_lighthouse_config() {
  # Build config.yaml for lighthouse
  local network="${1:-$NETWORK}"
  local output="${2:-$CONFIG_DIR/config.yaml}"
  shift 2 || true
  
  log_info "Building Lighthouse config for network: $network"
  bash "$ROOT_DIR/modules/lighthouse/build-config.sh" \
    --network "$network" \
    --output "$output" \
    "$@"
}

function ensure_lighthouse_config_files() {
  mkdir -p "$CONFIG_DIR"
  local config_file="$CONFIG_DIR/config.yaml"
  local deposit_block_file="$CONFIG_DIR/deposit_contract_block.txt"
  if [ ! -f "$config_file" ]; then
    log_info "config.yaml missing. Building default lighthouse config..."
    build_lighthouse_config "$NETWORK" "$config_file"
  fi
  if [ ! -f "$deposit_block_file" ]; then
    echo "$DEPOSIT_CONTRACT_BLOCK" > "$deposit_block_file"
    log_info "Created default deposit_contract_block.txt ($DEPOSIT_CONTRACT_BLOCK)"
  fi
}

function build_geth_genesis() {
  # Build genesis.json for geth
  local network="${1:-$NETWORK}"
  local output="${2:-$GENESIS_FILE}"
  shift 2 || true
  
  log_info "Building Geth genesis for network: $network"
  bash "$ROOT_DIR/modules/geth/build-genesis.sh" \
    --network "$network" \
    --output "$output" \
    "$@"
}

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

function log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

function log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

