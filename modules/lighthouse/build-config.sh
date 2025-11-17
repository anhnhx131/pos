#!/bin/bash
# Build config.yaml for Lighthouse consensus client
# Support multiple networks (joc, eth...) with default for joc

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Build config.yaml for Lighthouse consensus client"
  echo ""
  echo "Options:"
  echo "  --network <network>          Network name (joc, eth, etc.) (default: joc)"
  echo "  --preset-base <preset>       Preset base (gnosis, mainnet, etc.) (default: auto based on network)"
  echo "  --config-name <name>         Config name (default: network name)"
  echo "  --chain-id <id>              Chain ID (default: 84 for joc)"
  echo "  --network-id <id>            Network ID (default: 84 for joc)"
  echo "  --deposit-contract <addr>    Deposit contract address"
  echo "  --output <path>              Output config.yaml path (default: cl/config/config.yaml)"
  echo "  --override <key=value>       Override specific config value (can be used multiple times)"
  echo "  -h|--help                    Show this help"
  exit 1
}

# Default values
NETWORK="${NETWORK:-joc}"
PRESET_BASE=""
CONFIG_NAME=""
CHAIN_ID=""
NETWORK_ID=""
DEPOSIT_CONTRACT=""
OUTPUT="${CL_DIR}/config/config.yaml"
OVERRIDES=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --network)
      NETWORK="$2"
      shift 2
      ;;
    --preset-base)
      PRESET_BASE="$2"
      shift 2
      ;;
    --config-name)
      CONFIG_NAME="$2"
      shift 2
      ;;
    --chain-id)
      CHAIN_ID="$2"
      shift 2
      ;;
    --network-id)
      NETWORK_ID="$2"
      shift 2
      ;;
    --deposit-contract)
      DEPOSIT_CONTRACT="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --override)
      OVERRIDES+=("$2")
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

# Network presets
case "$NETWORK" in
  joc)
    PRESET_BASE="${PRESET_BASE:-gnosis}"
    CONFIG_NAME="${CONFIG_NAME:-joc}"
    CHAIN_ID="${CHAIN_ID:-84}"
    NETWORK_ID="${NETWORK_ID:-84}"
    DEPOSIT_CONTRACT="${DEPOSIT_CONTRACT:-0x4242424242424242424242424242424242424242}"
    # JOC specific defaults
    MIN_GENESIS_ACTIVE_VALIDATOR_COUNT="${MIN_GENESIS_ACTIVE_VALIDATOR_COUNT:-3}"
    MIN_GENESIS_TIME="${MIN_GENESIS_TIME:-1753840307}"
    GENESIS_FORK_VERSION="${GENESIS_FORK_VERSION:-0x00000084}"
    GENESIS_DELAY="${GENESIS_DELAY:-25}"
    EPOCHS_PER_ETH1_VOTING_PERIOD="${EPOCHS_PER_ETH1_VOTING_PERIOD:-1}"
    ALTAIR_FORK_VERSION="${ALTAIR_FORK_VERSION:-0x01000084}"
    ALTAIR_FORK_EPOCH="${ALTAIR_FORK_EPOCH:-1}"
    BELLATRIX_FORK_VERSION="${BELLATRIX_FORK_VERSION:-0x02000084}"
    BELLATRIX_FORK_EPOCH="${BELLATRIX_FORK_EPOCH:-3}"
    TERMINAL_TOTAL_DIFFICULTY="${TERMINAL_TOTAL_DIFFICULTY:-100}"
    TERMINAL_BLOCK_HASH="${TERMINAL_BLOCK_HASH:-0x0000000000000000000000000000000000000000000000000000000000000000}"
    TERMINAL_BLOCK_HASH_ACTIVATION_EPOCH="${TERMINAL_BLOCK_HASH_ACTIVATION_EPOCH:-18446744073709551615}"
    CAPELLA_FORK_VERSION="${CAPELLA_FORK_VERSION:-0x03000084}"
    CAPELLA_FORK_EPOCH="${CAPELLA_FORK_EPOCH:-7}"
    DENEB_FORK_VERSION="${DENEB_FORK_VERSION:-0x04000084}"
    DENEB_FORK_EPOCH="${DENEB_FORK_EPOCH:-10}"
    ELECTRA_FORK_VERSION="${ELECTRA_FORK_VERSION:-0x05000084}"
    ELECTRA_FORK_EPOCH="${ELECTRA_FORK_EPOCH:-13}"
    SECONDS_PER_SLOT="${SECONDS_PER_SLOT:-5}"
    SLOTS_PER_EPOCH="${SLOTS_PER_EPOCH:-5}"
    SECONDS_PER_ETH1_BLOCK="${SECONDS_PER_ETH1_BLOCK:-5}"
    MIN_VALIDATOR_WITHDRAWABILITY_DELAY="${MIN_VALIDATOR_WITHDRAWABILITY_DELAY:-5}"
    SHARD_COMMITTEE_PERIOD="${SHARD_COMMITTEE_PERIOD:-10}"
    ETH1_FOLLOW_DISTANCE="${ETH1_FOLLOW_DISTANCE:-1}"
    INACTIVITY_SCORE_BIAS="${INACTIVITY_SCORE_BIAS:-4}"
    INACTIVITY_SCORE_RECOVERY_RATE="${INACTIVITY_SCORE_RECOVERY_RATE:-16}"
    EJECTION_BALANCE="${EJECTION_BALANCE:-16000000000}"
    MIN_PER_EPOCH_CHURN_LIMIT="${MIN_PER_EPOCH_CHURN_LIMIT:-4}"
    CHURN_LIMIT_QUOTIENT="${CHURN_LIMIT_QUOTIENT:-4096}"
    PROPOSER_SCORE_BOOST="${PROPOSER_SCORE_BOOST:-40}"
    ;;
  eth|mainnet)
    PRESET_BASE="${PRESET_BASE:-mainnet}"
    CONFIG_NAME="${CONFIG_NAME:-mainnet}"
    CHAIN_ID="${CHAIN_ID:-1}"
    NETWORK_ID="${NETWORK_ID:-1}"
    DEPOSIT_CONTRACT="${DEPOSIT_CONTRACT:-0x00000000219ab540356cBB839Cbe05303d7705Fa}"
    # Ethereum mainnet defaults
    MIN_GENESIS_ACTIVE_VALIDATOR_COUNT="${MIN_GENESIS_ACTIVE_VALIDATOR_COUNT:-16384}"
    MIN_GENESIS_TIME="${MIN_GENESIS_TIME:-1606824023}"
    GENESIS_FORK_VERSION="${GENESIS_FORK_VERSION:-0x00000000}"
    GENESIS_DELAY="${GENESIS_DELAY:-604800}"
    EPOCHS_PER_ETH1_VOTING_PERIOD="${EPOCHS_PER_ETH1_VOTING_PERIOD:-64}"
    ALTAIR_FORK_VERSION="${ALTAIR_FORK_VERSION:-0x01000000}"
    ALTAIR_FORK_EPOCH="${ALTAIR_FORK_EPOCH:-74240}"
    BELLATRIX_FORK_VERSION="${BELLATRIX_FORK_VERSION:-0x02000000}"
    BELLATRIX_FORK_EPOCH="${BELLATRIX_FORK_EPOCH:-144896}"
    TERMINAL_TOTAL_DIFFICULTY="${TERMINAL_TOTAL_DIFFICULTY:-58750000000000000000000}"
    TERMINAL_BLOCK_HASH="${TERMINAL_BLOCK_HASH:-0x0000000000000000000000000000000000000000000000000000000000000000}"
    TERMINAL_BLOCK_HASH_ACTIVATION_EPOCH="${TERMINAL_BLOCK_HASH_ACTIVATION_EPOCH:-18446744073709551615}"
    CAPELLA_FORK_VERSION="${CAPELLA_FORK_VERSION:-0x03000000}"
    CAPELLA_FORK_EPOCH="${CAPELLA_FORK_EPOCH:-194048}"
    DENEB_FORK_VERSION="${DENEB_FORK_VERSION:-0x04000000}"
    DENEB_FORK_EPOCH="${DENEB_FORK_EPOCH:-269568}"
    ELECTRA_FORK_VERSION="${ELECTRA_FORK_VERSION:-0x05000000}"
    ELECTRA_FORK_EPOCH="${ELECTRA_FORK_EPOCH:-18446744073709551615}"
    SECONDS_PER_SLOT="${SECONDS_PER_SLOT:-12}"
    SLOTS_PER_EPOCH="${SLOTS_PER_EPOCH:-32}"
    SECONDS_PER_ETH1_BLOCK="${SECONDS_PER_ETH1_BLOCK:-14}"
    MIN_VALIDATOR_WITHDRAWABILITY_DELAY="${MIN_VALIDATOR_WITHDRAWABILITY_DELAY:-256}"
    SHARD_COMMITTEE_PERIOD="${SHARD_COMMITTEE_PERIOD:-256}"
    ETH1_FOLLOW_DISTANCE="${ETH1_FOLLOW_DISTANCE:-2048}"
    INACTIVITY_SCORE_BIAS="${INACTIVITY_SCORE_BIAS:-4}"
    INACTIVITY_SCORE_RECOVERY_RATE="${INACTIVITY_SCORE_RECOVERY_RATE:-16}"
    EJECTION_BALANCE="${EJECTION_BALANCE:-16000000000}"
    MIN_PER_EPOCH_CHURN_LIMIT="${MIN_PER_EPOCH_CHURN_LIMIT:-4}"
    CHURN_LIMIT_QUOTIENT="${CHURN_LIMIT_QUOTIENT:-65536}"
    PROPOSER_SCORE_BOOST="${PROPOSER_SCORE_BOOST:-40}"
    ;;
  *)
    log_error "Unknown network: $NETWORK"
    log_error "Supported networks: joc, eth (mainnet)"
    exit 1
    ;;
esac

# Apply overrides
for override in "${OVERRIDES[@]}"; do
  if [[ "$override" == *"="* ]]; then
    key="${override%%=*}"
    value="${override#*=}"
    export "$key"="$value"
    log_info "Override: $key=$value"
  else
    log_warn "Invalid override format: $override (should be key=value)"
  fi
done

# Create output directory if needed
mkdir -p "$(dirname "$OUTPUT")"

log_info "Building config.yaml for network: $NETWORK"
log_info "  Preset Base: $PRESET_BASE"
log_info "  Config Name: $CONFIG_NAME"
log_info "  Chain ID: $CHAIN_ID"
log_info "  Network ID: $NETWORK_ID"
log_info "  Deposit Contract: $DEPOSIT_CONTRACT"
log_info "  Output: $OUTPUT"

# Generate config.yaml
cat > "$OUTPUT" <<EOF
PRESET_BASE: '$PRESET_BASE'
CONFIG_NAME: '$CONFIG_NAME'

# Genesis
# ---------------------------------------------------------------
MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: $MIN_GENESIS_ACTIVE_VALIDATOR_COUNT
MIN_GENESIS_TIME: $MIN_GENESIS_TIME
GENESIS_FORK_VERSION: $GENESIS_FORK_VERSION
GENESIS_DELAY: $GENESIS_DELAY
EPOCHS_PER_ETH1_VOTING_PERIOD: $EPOCHS_PER_ETH1_VOTING_PERIOD

# Forking
# ---------------------------------------------------------------
# Some forks are disabled for now:
#  - These may be re-assigned to another fork-version later
#  - Temporarily set to max uint64 value: 2**64-1

# Altair
ALTAIR_FORK_VERSION: $ALTAIR_FORK_VERSION
ALTAIR_FORK_EPOCH: $ALTAIR_FORK_EPOCH

# Merge
BELLATRIX_FORK_VERSION: $BELLATRIX_FORK_VERSION
BELLATRIX_FORK_EPOCH: $BELLATRIX_FORK_EPOCH

# TBD: 2**256-1 is a placeholder
TERMINAL_TOTAL_DIFFICULTY: $TERMINAL_TOTAL_DIFFICULTY
TERMINAL_BLOCK_HASH: $TERMINAL_BLOCK_HASH
TERMINAL_BLOCK_HASH_ACTIVATION_EPOCH: $TERMINAL_BLOCK_HASH_ACTIVATION_EPOCH

# Shanghai fork
CAPELLA_FORK_VERSION: $CAPELLA_FORK_VERSION
CAPELLA_FORK_EPOCH: $CAPELLA_FORK_EPOCH

# Cancun
DENEB_FORK_VERSION: $DENEB_FORK_VERSION
DENEB_FORK_EPOCH: $DENEB_FORK_EPOCH

# Prague
ELECTRA_FORK_VERSION: $ELECTRA_FORK_VERSION
ELECTRA_FORK_EPOCH: $ELECTRA_FORK_EPOCH

# Sharding
# SHARDING_FORK_VERSION: 0x03000084
# SHARDING_FORK_EPOCH: 18446744073709551615

# Time parameters
# ---------------------------------------------------------------
# Seconds per slot
SECONDS_PER_SLOT: $SECONDS_PER_SLOT
SLOTS_PER_EPOCH: $SLOTS_PER_EPOCH
# Seconds per Eth1 block
SECONDS_PER_ETH1_BLOCK: $SECONDS_PER_ETH1_BLOCK
# 2**8 (= 256) epochs
MIN_VALIDATOR_WITHDRAWABILITY_DELAY: $MIN_VALIDATOR_WITHDRAWABILITY_DELAY
# 2**8 (= 256) epochs
SHARD_COMMITTEE_PERIOD: $SHARD_COMMITTEE_PERIOD
# 2**11 (= 2,048) Eth1 blocks
ETH1_FOLLOW_DISTANCE: $ETH1_FOLLOW_DISTANCE

# Validator cycle
# ---------------------------------------------------------------
# 2**2 (= 4)
INACTIVITY_SCORE_BIAS: $INACTIVITY_SCORE_BIAS
# 2**4 (= 16)
INACTIVITY_SCORE_RECOVERY_RATE: $INACTIVITY_SCORE_RECOVERY_RATE
# 2**4 * 10**9 (= 16,000,000,000) Gwei
EJECTION_BALANCE: $EJECTION_BALANCE
# 2**2 (= 4)
MIN_PER_EPOCH_CHURN_LIMIT: $MIN_PER_EPOCH_CHURN_LIMIT
# 2**16 (= 65,536)
CHURN_LIMIT_QUOTIENT: $CHURN_LIMIT_QUOTIENT
PROPOSER_SCORE_BOOST: $PROPOSER_SCORE_BOOST

# Deposit contract
# ---------------------------------------------------------------
DEPOSIT_CHAIN_ID: $CHAIN_ID
DEPOSIT_NETWORK_ID: $NETWORK_ID
DEPOSIT_CONTRACT_ADDRESS: $DEPOSIT_CONTRACT
EOF

log_info "Config.yaml generated successfully at: $OUTPUT"
log_info "Done!"

