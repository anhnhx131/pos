#!/bin/bash
# Create a Lighthouse Validator Client

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --name <name>             Container name (default: lighthouse-validator)"
  echo "  --beacon-endpoint <url>   Beacon node endpoint (required)"
  echo "  --beacon-container <name> Beacon node container name (alternative to --beacon-endpoint)"
  echo "  --keystore <json>         Validator keystore JSON"
  echo "  --keystore-file <path>    Path to validator keystore file"
  echo "  --password <pass>         Keystore password (default: from config)"
  echo "  --fee-recipient <addr>    Fee recipient address"
  echo "  --http-port <port>        Expose HTTP port on host"
  exit 1
}

VALIDATOR_NAME=""
BEACON_ENDPOINT=""
BEACON_CONTAINER=""
KEYSTORE=""
KEYSTORE_FILE=""
PASSWORD="$VALIDATOR_PASSWORD"
FEE_RECIPIENT="$DEFAULT_FEE_RECIPIENT"
HTTP_PORT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --name)
      VALIDATOR_NAME="$2"
      shift 2
      ;;
    --beacon-endpoint)
      BEACON_ENDPOINT="$2"
      shift 2
      ;;
    --beacon-container)
      BEACON_CONTAINER="$2"
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
    --password)
      PASSWORD="$2"
      shift 2
      ;;
    --fee-recipient)
      FEE_RECIPIENT="$2"
      shift 2
      ;;
    --http-port)
      HTTP_PORT="$2"
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
[ -z "$VALIDATOR_NAME" ] && VALIDATOR_NAME="lighthouse-validator"

# Determine beacon endpoint
if [ -z "$BEACON_ENDPOINT" ]; then
  if [ -n "$BEACON_CONTAINER" ]; then
    BEACON_ENDPOINT="http://${BEACON_CONTAINER}:3500"
  else
    log_error "Either --beacon-endpoint or --beacon-container must be specified"
    usage
  fi
fi

log_info "Creating Lighthouse Validator"
log_info "  Name: $VALIDATOR_NAME"
log_info "  Beacon: $BEACON_ENDPOINT"
log_info "  Fee Recipient: $FEE_RECIPIENT"

# Create network if not exists
create_docker_network

# Ensure config artifacts exist
ensure_lighthouse_config_files

# Create validator data directory
VALIDATOR_DIR="${CL_DIR}/validator"
mkdir -p "$VALIDATOR_DIR/validators"
mkdir -p "$VALIDATOR_DIR/validator_keys"

# Handle keystore
if [ -n "$KEYSTORE" ]; then
  log_info "Using provided keystore JSON"
  echo "$KEYSTORE" > "$VALIDATOR_DIR/validator_keys/keystore-$(date +%s).json"
elif [ -n "$KEYSTORE_FILE" ]; then
  log_info "Copying keystore from file: $KEYSTORE_FILE"
  cp "$KEYSTORE_FILE" "$VALIDATOR_DIR/validator_keys/"
else
  log_error "Either --keystore or --keystore-file must be provided"
  usage
fi

# Create password file
echo "$PASSWORD" > "$VALIDATOR_DIR/validator_keys/password.txt"

# Create API token
VALIDATOR_API_TOKEN="${VALIDATOR_API_TOKEN:-$(openssl rand -hex 16)}"
printf "$VALIDATOR_API_TOKEN" > "$VALIDATOR_DIR/validators/api-token.txt"

# Import keystore
log_info "Importing validator keystore..."
docker run --rm \
  -v "$VALIDATOR_DIR:/data" \
  -v "$CONFIG_DIR:/config" \
  $LIGHTHOUSE_IMAGE \
  lighthouse \
  account_manager \
  validator \
  import \
  --datadir=/data \
  --directory=/data/validator_keys \
  --password-file=/data/validator_keys/password.txt \
  --testnet-dir=/config \
  --reuse-password

# Stop and remove existing validator if running
if docker ps -a --format '{{.Names}}' | grep -q "^${VALIDATOR_NAME}$"; then
  log_warn "Stopping existing validator: $VALIDATOR_NAME"
  docker stop $VALIDATOR_NAME >/dev/null 2>&1 || true
  docker rm $VALIDATOR_NAME >/dev/null 2>&1 || true
fi

# Build docker command
DOCKER_CMD="docker run -d --name $VALIDATOR_NAME --network $DOCKER_NETWORK_NAME"

# Add port mapping if specified
[ -n "$HTTP_PORT" ] && DOCKER_CMD="$DOCKER_CMD -p ${HTTP_PORT}:5062"

# Add volumes
DOCKER_CMD="$DOCKER_CMD -v $VALIDATOR_DIR:/data -v $CONFIG_DIR:/config"

# Add lighthouse command
DOCKER_CMD="$DOCKER_CMD $LIGHTHOUSE_IMAGE lighthouse validator_client"
DOCKER_CMD="$DOCKER_CMD --validators-dir=/data/validators"
DOCKER_CMD="$DOCKER_CMD --testnet-dir=/config"
DOCKER_CMD="$DOCKER_CMD --beacon-nodes=$BEACON_ENDPOINT"
DOCKER_CMD="$DOCKER_CMD --http"
DOCKER_CMD="$DOCKER_CMD --http-address=0.0.0.0"
DOCKER_CMD="$DOCKER_CMD --unencrypted-http-transport"
DOCKER_CMD="$DOCKER_CMD --http-port=5062"
DOCKER_CMD="$DOCKER_CMD --http-allow-origin=*"
DOCKER_CMD="$DOCKER_CMD --suggested-fee-recipient=$FEE_RECIPIENT"

# Run validator
log_info "Starting Lighthouse validator..."
eval $DOCKER_CMD

log_info "Lighthouse validator started successfully!"
log_info "Container: $VALIDATOR_NAME"
[ -n "$HTTP_PORT" ] && log_info "HTTP API: http://localhost:${HTTP_PORT}"
log_info "Internal HTTP API: http://${VALIDATOR_NAME}:5062"
log_info "API Token: $VALIDATOR_API_TOKEN"

log_info "Done!"

