#!/bin/bash
# Build explorer-config.yaml for Dora Beacon Chain Explorer
# Follows the structure of example.config.yaml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Set ROOT_DIR if not already set (allows override from parent scripts)
export ROOT_DIR="${ROOT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$ROOT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Build explorer-config.yaml for Dora Beacon Chain Explorer"
  echo ""
  echo "Options:"
  echo "  --beacon-rpc <url>          Beacon RPC endpoint URL (required, can be used multiple times)"
  echo "  --execution-rpc <url>       Execution RPC endpoint URL (required, can be used multiple times)"
  echo "  --port <port>               Dora server port (default: 8080)"
  echo "  --host <host>               Dora server host (default: 0.0.0.0)"
  echo "  --site-name <name>          Site name (default: Dora the Explorer)"
  echo "  --site-subtitle <text>      Site subtitle"
  echo "  --eth-explorer-link <url>   Link to EL Explorer"
  echo "  --public-rpc-url <url>      Public RPC URL for frontend"
  echo "  --deposit-deploy-block <n>  Deposit contract deployment block (default: 0)"
  echo "  --electra-deploy-block <n>  Electra system contracts deployment block (default: 0)"
  echo "  --database-engine <engine>  Database engine: sqlite or pgsql (default: sqlite)"
  echo "  --output <path>             Output config file path (default: dora/explorer-config.yaml)"
  echo "  -h|--help                   Show this help"
  exit 1
}

# Default values
BEACON_RPC_URLS=()
EXECUTION_RPC_URLS=()
PORT="${DORA_PORT:-8080}"
HOST="0.0.0.0"
SITE_NAME="Dora the Explorer"
SITE_SUBTITLE=""
ETH_EXPLORER_LINK=""
PUBLIC_RPC_URL=""
DEPOSIT_DEPLOY_BLOCK="0"
ELECTRA_DEPLOY_BLOCK="0"
DATABASE_ENGINE="sqlite"
OUTPUT="${ROOT_DIR}/dora/explorer-config.yaml"

while [[ $# -gt 0 ]]; do
  case $1 in
    --beacon-rpc)
      BEACON_RPC_URLS+=("$2")
      shift 2
      ;;
    --execution-rpc)
      EXECUTION_RPC_URLS+=("$2")
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    --site-name)
      SITE_NAME="$2"
      shift 2
      ;;
    --site-subtitle)
      SITE_SUBTITLE="$2"
      shift 2
      ;;
    --eth-explorer-link)
      ETH_EXPLORER_LINK="$2"
      shift 2
      ;;
    --public-rpc-url)
      PUBLIC_RPC_URL="$2"
      shift 2
      ;;
    --deposit-deploy-block)
      DEPOSIT_DEPLOY_BLOCK="$2"
      shift 2
      ;;
    --electra-deploy-block)
      ELECTRA_DEPLOY_BLOCK="$2"
      shift 2
      ;;
    --database-engine)
      DATABASE_ENGINE="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
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

# Validate required parameters
if [ ${#BEACON_RPC_URLS[@]} -eq 0 ]; then
  log_error "At least one --beacon-rpc URL is required"
  usage
fi

if [ ${#EXECUTION_RPC_URLS[@]} -eq 0 ]; then
  log_error "At least one --execution-rpc URL is required"
  usage
fi

# Set default public RPC URL if not provided (use first execution RPC)
if [ -z "$PUBLIC_RPC_URL" ]; then
  PUBLIC_RPC_URL="${EXECUTION_RPC_URLS[0]}"
fi

# Create output directory if needed
mkdir -p "$(dirname "$OUTPUT")"

log_info "Building Dora explorer config"
log_info "  Beacon RPC endpoints: ${#BEACON_RPC_URLS[@]}"
for i in "${!BEACON_RPC_URLS[@]}"; do
  log_info "    [$i] ${BEACON_RPC_URLS[$i]}"
done
log_info "  Execution RPC endpoints: ${#EXECUTION_RPC_URLS[@]}"
for i in "${!EXECUTION_RPC_URLS[@]}"; do
  log_info "    [$i] ${EXECUTION_RPC_URLS[$i]}"
done
log_info "  Port: $PORT"
log_info "  Host: $HOST"
log_info "  Site Name: $SITE_NAME"
log_info "  Database Engine: $DATABASE_ENGINE"
log_info "  Output: $OUTPUT"

# Generate config.yaml
cat > "$OUTPUT" <<EOF
logging:
  #outputLevel: "info"
  #outputStderr: false
  #filePath: "explorer.log"
  #fileLevel: "warn"

# Chain network configuration
chain:
  #displayName: "Ephemery Iteration xy"

# HTTP Server configuration
server:
  host: "${HOST}"
  port: "${PORT}"

frontend:
  enabled: true
  debug: false
  minimize: false
  siteName: "${SITE_NAME}"
EOF

# Add site subtitle if provided
if [ -n "$SITE_SUBTITLE" ]; then
  cat >> "$OUTPUT" <<EOF
  siteSubtitle: "${SITE_SUBTITLE}"
EOF
else
  cat >> "$OUTPUT" <<EOF
  siteSubtitle: ""
EOF
fi

# Add eth explorer link if provided
if [ -n "$ETH_EXPLORER_LINK" ]; then
  cat >> "$OUTPUT" <<EOF
  ethExplorerLink: "${ETH_EXPLORER_LINK}"
EOF
else
  cat >> "$OUTPUT" <<EOF
  ethExplorerLink: ""
EOF
fi

cat >> "$OUTPUT" <<EOF
  validatorNamesYaml: ""
  validatorNamesInventory: ""
  disablePageCache: false
  showSensitivePeerInfos: false
  showPeerDASInfos: false
  showSubmitDeposit: false
  showSubmitElRequests: false
  publicRpcUrl: "${PUBLIC_RPC_URL}"

beaconapi:
  endpoints:
EOF

# Add beacon endpoints
for i in "${!BEACON_RPC_URLS[@]}"; do
  if [ $i -eq 0 ]; then
    cat >> "$OUTPUT" <<EOF
    - name: "primary"
      url: "${BEACON_RPC_URLS[$i]}"
EOF
  else
    cat >> "$OUTPUT" <<EOF
    - name: "beacon$((i+1))"
      url: "${BEACON_RPC_URLS[$i]}"
EOF
  fi
done

cat >> "$OUTPUT" <<EOF
  localCacheSize: 100
  redisCacheAddr: ""
  redisCachePrefix: ""

executionapi:
  endpoints:
EOF

# Add execution endpoints
for i in "${!EXECUTION_RPC_URLS[@]}"; do
  if [ $i -eq 0 ]; then
    cat >> "$OUTPUT" <<EOF
    - name: "primary"
      url: "${EXECUTION_RPC_URLS[$i]}"
EOF
  else
    cat >> "$OUTPUT" <<EOF
    - name: "execution$((i+1))"
      url: "${EXECUTION_RPC_URLS[$i]}"
EOF
  fi
done

cat >> "$OUTPUT" <<EOF
  logBatchSize: 1000
  depositDeployBlock: ${DEPOSIT_DEPLOY_BLOCK}
  electraDeployBlock: ${ELECTRA_DEPLOY_BLOCK}
  genesisConfig: ""

indexer:
  inMemoryEpochs: 3
  activityHistoryLength: 6
  disableSynchronizer: false
  syncEpochCooldown: 2
  maxParallelValidatorSetRequests: 1

database:
  engine: "${DATABASE_ENGINE}"
EOF

# Add database-specific settings
if [ "$DATABASE_ENGINE" = "sqlite" ]; then
  cat >> "$OUTPUT" <<EOF
  sqlite:
    file: "./explorer-db.sqlite"
  pgsql:
    host: "127.0.0.1"
    port: 5432
    user: ""
    password: ""
    name: ""
  pgsqlWriter:
    host: ""
    port: 5432
    user: ""
    password: ""
    name: ""
EOF
elif [ "$DATABASE_ENGINE" = "pgsql" ]; then
  cat >> "$OUTPUT" <<EOF
  sqlite:
    file: "./explorer-db.sqlite"
  pgsql:
    host: "127.0.0.1"
    port: 5432
    user: ""
    password: ""
    name: ""
  pgsqlWriter:
    host: ""
    port: 5432
    user: ""
    password: ""
    name: ""
EOF
fi

cat >> "$OUTPUT" <<EOF

blockDb:
  engine: "none"
  pebble:
    path: "./tmp-blockdb.peb"
    cacheSize: 100
  s3:
    bucket: ""
    endpoint: ""
    secure: false
    region: ""
    accessKey: ""
    secretKey: ""
    path: ""
EOF

log_info "Dora explorer config generated successfully at: $OUTPUT"
log_info "Done!"

