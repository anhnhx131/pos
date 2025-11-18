#!/bin/bash
# Create Geth Bootnode

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --name <name>       Container name (default: geth-bootnode)"
  echo "  --key <key>         Bootnode key (default: from config)"
  exit 1
}

BOOTNODE_NAME=""
BOOTNODE_KEY="${GETH_BOOTNODE_KEY}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --name)
      BOOTNODE_NAME="$2"
      shift 2
      ;;
    --key)
      BOOTNODE_KEY="$2"
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
[ -z "$BOOTNODE_NAME" ] && BOOTNODE_NAME="geth-bootnode"

log_info "Creating Geth Bootnode"
log_info "  Name: $BOOTNODE_NAME"

# Create network if not exists
create_docker_network

# Create bootnode data directory
BOOTNODE_DIR="${EL_DIR}/geth/${BOOTNODE_NAME}"
mkdir -p "$BOOTNODE_DIR"
echo "$BOOTNODE_KEY" > "$BOOTNODE_DIR/boot.key"
echo "$JWT_SECRET" > "$BOOTNODE_DIR/jwtsecret"

# Initialize bootnode if not already initialized
if [ ! -d "$BOOTNODE_DIR/geth" ]; then
  log_info "Initializing bootnode with genesis..."
  docker run --rm \
    -v "$BOOTNODE_DIR:/.ethereum" \
    -v "$GENESIS_FILE:/.genesis.json" \
    $GETH_IMAGE \
    --datadir /.ethereum init /.genesis.json
fi

# Stop and remove existing bootnode if running
if docker ps -a --format '{{.Names}}' | grep -q "^${BOOTNODE_NAME}$"; then
  log_warn "Stopping existing bootnode: $BOOTNODE_NAME"
  docker stop $BOOTNODE_NAME >/dev/null 2>&1 || true
  docker rm $BOOTNODE_NAME >/dev/null 2>&1 || true
fi

# Run bootnode
log_info "Starting Geth bootnode..."
docker run -d \
  --name $BOOTNODE_NAME \
  --network $DOCKER_NETWORK_NAME \
  -p 30303:30303 \
  -p 30303:30303/udp \
  -v "$BOOTNODE_DIR:/.ethereum" \
  $GETH_IMAGE \
  --datadir=/.ethereum \
  --networkid=$NETWORK_ID \
  --nodekey /.ethereum/boot.key \
  --syncmode=full \
  --verbosity=3

log_info "Geth bootnode started successfully!"
log_info "Bootnode container: $BOOTNODE_NAME"

# Wait for bootnode to start
sleep 3

# Get enode from logs
log_info "Extracting enode information..."
docker logs $BOOTNODE_NAME 2>&1 | grep -o "enode://[a-f0-9]*@.*:30303" | head -n 1 || log_warn "Could not extract enode yet, check logs later"

log_info "Done! Bootnode container: $BOOTNODE_NAME"

