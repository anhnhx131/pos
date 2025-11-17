#!/bin/bash
# Start Dora Beacon Chain Explorer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --port <port>             Dora port (default: 8080)"
  echo "  --config <file>           Config file path (default: dora/explorer-config.yaml)"
  exit 1
}

PORT="${DORA_PORT}"
CONFIG_FILE="${ROOT_DIR}/dora/explorer-config.yaml"

while [[ $# -gt 0 ]]; do
  case $1 in
    --port)
      PORT="$2"
      shift 2
      ;;
    --config)
      CONFIG_FILE="$2"
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

log_info "Starting Dora Beacon Chain Explorer"
log_info "  Port: $PORT"
log_info "  Config: $CONFIG_FILE"

# Create network if not exists
create_docker_network

# Stop existing container if running
if docker ps -a --format '{{.Names}}' | grep -q "^pos-dora$"; then
  log_warn "Stopping existing Dora container"
  docker stop pos-dora >/dev/null 2>&1 || true
  docker rm pos-dora >/dev/null 2>&1 || true
fi

# Run Dora
log_info "Starting Dora container..."
docker run -d \
  --network $DOCKER_NETWORK_NAME \
  --name pos-dora \
  -p $PORT:8080 \
  -v "$CONFIG_FILE:/explorer-config.yaml" \
  $DORA_IMAGE \
  -config=/explorer-config.yaml

log_info "Dora started successfully!"
log_info "Access at: http://localhost:$PORT"
log_info "Done!"

