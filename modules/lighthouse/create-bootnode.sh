#!/bin/bash
# Create Lighthouse Beacon Chain Bootnode

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 <bootnode_index> [options]"
  echo ""
  echo "Options:"
  echo "  --ip <ip>           Bootnode IP address (default: 10.7.2.<index+2>)"
  echo "  --name <name>       Container name (default: lighthouse-bootnode-<index>)"
  exit 1
}

BOOTNODE_INDEX=""
BOOTNODE_IP=""
BOOTNODE_NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --ip)
      BOOTNODE_IP="$2"
      shift 2
      ;;
    --name)
      BOOTNODE_NAME="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      if [ -z "$BOOTNODE_INDEX" ]; then
        BOOTNODE_INDEX="$1"
      else
        echo "Unknown option: $1"
        usage
      fi
      shift
      ;;
  esac
done

if [ -z "$BOOTNODE_INDEX" ]; then
  log_error "Bootnode index is required"
  usage
fi

# Set defaults
[ -z "$BOOTNODE_IP" ] && BOOTNODE_IP="10.7.2.$((BOOTNODE_INDEX+2))"
[ -z "$BOOTNODE_NAME" ] && BOOTNODE_NAME="lighthouse-bootnode-${BOOTNODE_INDEX}"

log_info "Creating Lighthouse Bootnode"
log_info "  Index: $BOOTNODE_INDEX"
log_info "  Name: $BOOTNODE_NAME"
log_info "  IP: $BOOTNODE_IP"

# Create network if not exists
create_docker_network

# Create bootnode data directory
BOOTNODE_DIR="${CL_DIR}/bn${BOOTNODE_INDEX}"
mkdir -p "$BOOTNODE_DIR"

# Stop and remove existing bootnode if running
if docker ps -a --format '{{.Names}}' | grep -q "^${BOOTNODE_NAME}$"; then
  log_warn "Stopping existing bootnode: $BOOTNODE_NAME"
  docker stop $BOOTNODE_NAME >/dev/null 2>&1 || true
  docker rm $BOOTNODE_NAME >/dev/null 2>&1 || true
fi

# Run bootnode
log_info "Starting Lighthouse bootnode..."
docker run -d \
  --name $BOOTNODE_NAME \
  --network $DOCKER_NETWORK_NAME \
  --ip $BOOTNODE_IP \
  -v "$BOOTNODE_DIR:/data" \
  -v "$CONFIG_DIR:/config" \
  $LIGHTHOUSE_IMAGE \
  lighthouse \
  boot_node \
  --datadir=/data \
  --testnet-dir=/config \
  --disable-packet-filter \
  --enable-enr-auto-update \
  --listen-address=$BOOTNODE_IP \
  --enr-address=$BOOTNODE_IP

log_info "Lighthouse bootnode started successfully!"

# Wait for bootnode to generate ENR
sleep 3

# Try to read ENR
ENR_FILE="$BOOTNODE_DIR/beacon/network/enr.dat"
if [ -f "$ENR_FILE" ]; then
  ENR=$(cat "$ENR_FILE")
  log_info "Bootnode ENR: $ENR"
else
  log_warn "ENR file not yet created. Check logs: docker logs $BOOTNODE_NAME"
fi

log_info "Done! Bootnode container: $BOOTNODE_NAME"
