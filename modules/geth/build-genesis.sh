#!/bin/bash
# Build genesis.json for Geth execution client
# Support multiple networks (joc, eth...) with default for joc

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Build genesis.json for Geth execution client"
  echo ""
  echo "Options:"
  echo "  --network <network>          Network name (joc, eth, etc.) (default: joc)"
  echo "  --chain-id <id>              Chain ID (default: 84 for joc)"
  echo "  --network-id <id>            Network ID (default: 84 for joc)"
  echo "  --timestamp <timestamp>      Genesis timestamp (default: 0x0)"
  echo "  --gas-limit <limit>          Genesis gas limit (default: 0x5f5e100)"
  echo "  --terminal-total-difficulty <ttd> Terminal total difficulty"
  echo "  --shanghai-time <time>       Shanghai fork time"
  echo "  --cancun-time <time>         Cancun fork time"
  echo "  --prague-time <time>         Prague fork time"
  echo "  --output <path>              Output genesis.json path (default: el/geth/genesis.json)"
  echo "  --override <key=value>       Override specific config value (can be used multiple times)"
  echo "  -h|--help                    Show this help"
  exit 1
}

# Default values
NETWORK="${NETWORK:-joc}"
CHAIN_ID=""
NETWORK_ID=""
TIMESTAMP="0x0"
GAS_LIMIT="0x5f5e100"
TERMINAL_TOTAL_DIFFICULTY=""
SHANGHAI_TIME=""
CANCUN_TIME=""
PRAGUE_TIME=""
OUTPUT="${EL_DIR}/geth/genesis.json"
OVERRIDES=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --network)
      NETWORK="$2"
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
    --timestamp)
      TIMESTAMP="$2"
      shift 2
      ;;
    --gas-limit)
      GAS_LIMIT="$2"
      shift 2
      ;;
    --terminal-total-difficulty)
      TERMINAL_TOTAL_DIFFICULTY="$2"
      shift 2
      ;;
    --shanghai-time)
      SHANGHAI_TIME="$2"
      shift 2
      ;;
    --cancun-time)
      CANCUN_TIME="$2"
      shift 2
      ;;
    --prague-time)
      PRAGUE_TIME="$2"
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
    CHAIN_ID="${CHAIN_ID:-84}"
    NETWORK_ID="${NETWORK_ID:-84}"
    TERMINAL_TOTAL_DIFFICULTY="${TERMINAL_TOTAL_DIFFICULTY:-100}"
    SHANGHAI_TIME="${SHANGHAI_TIME:-9999999999999}"
    CANCUN_TIME="${CANCUN_TIME:-9999999999999}"
    PRAGUE_TIME="${PRAGUE_TIME:-9999999999999}"
    CLIQUE_PERIOD="${CLIQUE_PERIOD:-5}"
    CLIQUE_EPOCH="${CLIQUE_EPOCH:-30000}"
    EXTRA_DATA="${EXTRA_DATA:-0x000000000000000000000000000000000000000000000000000000000000000050bdda5a6c6e1c30ed6928ad65a4a57ceaf0ab2b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000}"
    ;;
  eth|mainnet)
    CHAIN_ID="${CHAIN_ID:-1}"
    NETWORK_ID="${NETWORK_ID:-1}"
    TERMINAL_TOTAL_DIFFICULTY="${TERMINAL_TOTAL_DIFFICULTY:-58750000000000000000000}"
    SHANGHAI_TIME="${SHANGHAI_TIME:-1681338455}"
    CANCUN_TIME="${CANCUN_TIME:-1710388139}"
    PRAGUE_TIME="${PRAGUE_TIME:-9999999999999}"
    CLIQUE_PERIOD="${CLIQUE_PERIOD:-15}"
    CLIQUE_EPOCH="${CLIQUE_EPOCH:-30000}"
    EXTRA_DATA="${EXTRA_DATA:-0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000}"
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

# For mainnet (eth), if genesis.json already exists, just use it
# Genesis for mainnet should be retrieved from mainnet, not generated
if [[ "$NETWORK" == "eth" || "$NETWORK" == "mainnet" ]]; then
  if [[ -f "$OUTPUT" ]]; then
    log_info "Genesis.json already exists for network: $NETWORK"
    log_info "Using existing genesis.json at: $OUTPUT"
    log_info "Note: For mainnet, genesis.json should be retrieved from mainnet, not generated"
    exit 0
  else
    log_warn "Genesis.json not found for mainnet. Creating a basic one without deposit contract."
    log_warn "For mainnet, you should retrieve genesis.json from mainnet instead of generating it."
    # For mainnet, don't include deposit contract in alloc since it's not in the actual mainnet genesis
  fi
fi

log_info "Building genesis.json for network: $NETWORK"
log_info "  Chain ID: $CHAIN_ID"
log_info "  Network ID: $NETWORK_ID"
log_info "  Terminal Total Difficulty: $TERMINAL_TOTAL_DIFFICULTY"
log_info "  Shanghai Time: $SHANGHAI_TIME"
log_info "  Cancun Time: $CANCUN_TIME"
log_info "  Prague Time: $PRAGUE_TIME"
log_info "  Output: $OUTPUT"

# Generate genesis.json using jq or cat with template
if command -v jq >/dev/null 2>&1; then
  # Use jq to generate JSON if available
  jq -n \
    --arg chainId "$CHAIN_ID" \
    --arg networkId "$NETWORK_ID" \
    --arg timestamp "$TIMESTAMP" \
    --arg gasLimit "$GAS_LIMIT" \
    --arg terminalTotalDifficulty "$TERMINAL_TOTAL_DIFFICULTY" \
    --arg shanghaiTime "$SHANGHAI_TIME" \
    --arg cancunTime "$CANCUN_TIME" \
    --arg pragueTime "$PRAGUE_TIME" \
    --arg cliquePeriod "$CLIQUE_PERIOD" \
    --arg cliqueEpoch "$CLIQUE_EPOCH" \
    --arg extraData "$EXTRA_DATA" \
    '{
      config: {
        chainId: ($chainId | tonumber),
        homesteadBlock: 0,
        eip150Block: 0,
        eip150Hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
        eip155Block: 0,
        eip158Block: 0,
        byzantiumBlock: 0,
        constantinopleBlock: 0,
        petersburgBlock: 0,
        istanbulBlock: 0,
        MuirGlacierBlock: 0,
        clique: {
          period: ($cliquePeriod | tonumber),
          epoch: ($cliqueEpoch | tonumber)
        },
        londonBlock: 0,
        muirGlacierBlock: 0,
        berlinBlock: 0,
        terminalTotalDifficulty: ($terminalTotalDifficulty | tonumber),
        shanghaiTime: ($shanghaiTime | tonumber),
        cancunTime: ($cancunTime | tonumber),
        pragueTime: ($pragueTime | tonumber),
        blobSchedule: {
          cancun: {
            target: 3,
            max: 6,
            baseFeeUpdateFraction: 3338477
          },
          prague: {
            target: 3,
            max: 6,
            baseFeeUpdateFraction: 3338477
          }
        }
      },
      nonce: "0x0",
      timestamp: $timestamp,
      extraData: $extraData,
      gasLimit: $gasLimit,
      difficulty: "0x1",
      mixHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
      coinbase: "0x0000000000000000000000000000000000000000",
      alloc: {
        "0xa66Be233CF5a5193b54fFfbF8C20754dF73c70Df": {
          balance: "0x0000000000000000000000000000000000000000033B2E3C9FD0803CE8000000"
        }
      },
      number: "0x0",
      gasUsed: "0x0",
      parentHash: "0x0000000000000000000000000000000000000000000000000000000000000000"
    }' > "$OUTPUT"
else
  # Fallback to cat if jq is not available
  cat > "$OUTPUT" <<EOF
{
  "config": {
    "chainId": $CHAIN_ID,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip150Hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "MuirGlacierBlock": 0,
    "clique": {
      "period": $CLIQUE_PERIOD,
      "epoch": $CLIQUE_EPOCH
    },
    "londonBlock": 0,
    "muirGlacierBlock": 0,
    "berlinBlock": 0,
    "terminalTotalDifficulty": "$TERMINAL_TOTAL_DIFFICULTY",
    "shanghaiTime": $SHANGHAI_TIME,
    "cancunTime": $CANCUN_TIME,
    "pragueTime": $PRAGUE_TIME,
    "blobSchedule": {
      "cancun": {
        "target": 3,
        "max": 6,
        "baseFeeUpdateFraction": 3338477
      },
      "prague": {
        "target": 3,
        "max": 6,
        "baseFeeUpdateFraction": 3338477
      }
    }
  },
  "nonce": "0x0",
  "timestamp": "$TIMESTAMP",
  "extraData": "$EXTRA_DATA",
  "gasLimit": "$GAS_LIMIT",
  "difficulty": "0x1",
  "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "coinbase": "0x0000000000000000000000000000000000000000",
  "alloc": {
    "0xa66Be233CF5a5193b54fFfbF8C20754dF73c70Df": {
      "balance": "0x0000000000000000000000000000000000000000033B2E3C9FD0803CE8000000"
    }
  },
  "number": "0x0",
  "gasUsed": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000"
}
EOF
fi

log_info "Genesis.json generated successfully at: $OUTPUT"
log_info "Done!"

