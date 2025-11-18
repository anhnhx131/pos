#!/bin/bash
# Create a Lighthouse Beacon Node

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --name <name>             Container name (default: lighthouse-beacon)"
  echo "  --el-endpoint <url>       Execution layer endpoint (required)"
  echo "  --el-container <name>     Execution layer container name (alternative to --el-endpoint)"
  echo "  --boot-nodes <enr,enr>    Comma-separated list of boot node ENRs"
  echo "  --http-port <port>        Expose HTTP port on host"
  echo "  --enable-gui              Enable Lighthouse GUI"
  exit 1
}

NODE_NAME=""
EL_ENDPOINT=""
EL_CONTAINER=""
BOOT_NODES="$LIGHTHOUSE_BOOTNODES"
HTTP_PORT=""
ENABLE_GUI=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --name)
      NODE_NAME="$2"
      shift 2
      ;;
    --el-endpoint)
      EL_ENDPOINT="$2"
      shift 2
      ;;
    --el-container)
      EL_CONTAINER="$2"
      shift 2
      ;;
    --boot-nodes)
      BOOT_NODES="$2"
      shift 2
      ;;
    --http-port)
      HTTP_PORT="$2"
      shift 2
      ;;
    --enable-gui)
      ENABLE_GUI=true
      shift
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
[ -z "$NODE_NAME" ] && NODE_NAME="lighthouse-beacon"

# Determine EL endpoint
if [ -z "$EL_ENDPOINT" ]; then
  if [ -n "$EL_CONTAINER" ]; then
    EL_ENDPOINT="http://${EL_CONTAINER}:8551"
  else
    log_error "Either --el-endpoint or --el-container must be specified"
    usage
  fi
fi

log_info "Creating Lighthouse Beacon Node"
log_info "  Name: $NODE_NAME"
log_info "  EL Endpoint: $EL_ENDPOINT"

# Create network if not exists
create_docker_network

# Ensure node directories and config
ensure_node_directories

# Create beacon node data directory
BEACON_DIR="$NODE_CL_DIR"
mkdir -p "$BEACON_DIR"

# Stop and remove existing node if running
if docker ps -a --format '{{.Names}}' | grep -q "^${NODE_NAME}$"; then
  log_warn "Stopping existing beacon node: $NODE_NAME"
  docker stop $NODE_NAME >/dev/null 2>&1 || true
  docker rm $NODE_NAME >/dev/null 2>&1 || true
fi

# Build docker command
DOCKER_CMD="docker run -d --name $NODE_NAME --network $DOCKER_NETWORK_NAME"

# Add port mapping if specified
[ -n "$HTTP_PORT" ] && DOCKER_CMD="$DOCKER_CMD -p ${HTTP_PORT}:3500"

# Add volumes
DOCKER_CMD="$DOCKER_CMD -v $BEACON_DIR:/data -v $NODE_CONFIG_DIR:/config"

# Add lighthouse command
DOCKER_CMD="$DOCKER_CMD $LIGHTHOUSE_IMAGE lighthouse beacon_node"
DOCKER_CMD="$DOCKER_CMD --datadir=/data"
DOCKER_CMD="$DOCKER_CMD --eth1"
DOCKER_CMD="$DOCKER_CMD --http"
DOCKER_CMD="$DOCKER_CMD --http-address=0.0.0.0"
DOCKER_CMD="$DOCKER_CMD --http-port=3500"
DOCKER_CMD="$DOCKER_CMD --http-allow-origin=*"
DOCKER_CMD="$DOCKER_CMD --debug-level=debug"
DOCKER_CMD="$DOCKER_CMD --execution-endpoint=$EL_ENDPOINT"
DOCKER_CMD="$DOCKER_CMD --execution-jwt=/config/jwtsecret"
DOCKER_CMD="$DOCKER_CMD --testnet-dir=/config"
DOCKER_CMD="$DOCKER_CMD --disable-upnp"
DOCKER_CMD="$DOCKER_CMD --enr-tcp-port=9000"
DOCKER_CMD="$DOCKER_CMD --enr-udp-port=9000"
DOCKER_CMD="$DOCKER_CMD --enable-private-discovery"

# Add boot nodes if specified
[ -n "$BOOT_NODES" ] && DOCKER_CMD="$DOCKER_CMD --boot-nodes=$BOOT_NODES"

# Add GUI if enabled
[ "$ENABLE_GUI" = true ] && DOCKER_CMD="$DOCKER_CMD --gui"

# Run beacon node
log_info "Starting Lighthouse beacon node..."
eval $DOCKER_CMD

log_info "Lighthouse beacon node started successfully!"
log_info "Container: $NODE_NAME"
[ -n "$HTTP_PORT" ] && log_info "HTTP API: http://localhost:${HTTP_PORT}"
log_info "Internal HTTP API: http://${NODE_NAME}:3500"

log_info "Done!"

