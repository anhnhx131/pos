#!/bin/bash
# Create a Lighthouse Beacon Node

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 <node_index> [options]"
  echo ""
  echo "Options:"
  echo "  --ip <ip>                 Beacon node IP (default: auto-assign)"
  echo "  --name <name>             Container name (default: lighthouse-beacon-<index>)"
  echo "  --el-endpoint <url>       Execution layer endpoint (required)"
  echo "  --el-ip <ip>              Execution layer IP (alternative to --el-endpoint)"
  echo "  --boot-nodes <enr,enr>    Comma-separated list of boot node ENRs"
  echo "  --http-port <port>        Expose HTTP port on host"
  echo "  --enable-gui              Enable Lighthouse GUI"
  exit 1
}

NODE_INDEX=""
NODE_IP=""
NODE_NAME=""
EL_ENDPOINT=""
EL_IP=""
BOOT_NODES="$LIGHTHOUSE_BOOTNODES"
HTTP_PORT=""
ENABLE_GUI=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --ip)
      NODE_IP="$2"
      shift 2
      ;;
    --name)
      NODE_NAME="$2"
      shift 2
      ;;
    --el-endpoint)
      EL_ENDPOINT="$2"
      shift 2
      ;;
    --el-ip)
      EL_IP="$2"
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
      if [ -z "$NODE_INDEX" ]; then
        NODE_INDEX="$1"
      else
        echo "Unknown option: $1"
        usage
      fi
      shift
      ;;
  esac
done

if [ -z "$NODE_INDEX" ]; then
  log_error "Node index is required"
  usage
fi

# Set defaults
[ -z "$NODE_IP" ] && NODE_IP=$(get_next_cl_ip $NODE_INDEX)
[ -z "$NODE_NAME" ] && NODE_NAME="lighthouse-beacon-${NODE_INDEX}"

# Determine EL endpoint
if [ -z "$EL_ENDPOINT" ]; then
  if [ -n "$EL_IP" ]; then
    EL_ENDPOINT="http://${EL_IP}:8551"
  else
    log_error "Either --el-endpoint or --el-ip must be specified"
    usage
  fi
fi

log_info "Creating Lighthouse Beacon Node"
log_info "  Index: $NODE_INDEX"
log_info "  Name: $NODE_NAME"
log_info "  IP: $NODE_IP"
log_info "  EL Endpoint: $EL_ENDPOINT"

# Create network if not exists
create_docker_network

# Create beacon node data directory
BEACON_DIR="${CL_DIR}/beacon-${NODE_INDEX}"
mkdir -p "$BEACON_DIR"

# Stop and remove existing node if running
if docker ps -a --format '{{.Names}}' | grep -q "^${NODE_NAME}$"; then
  log_warn "Stopping existing beacon node: $NODE_NAME"
  docker stop $NODE_NAME >/dev/null 2>&1 || true
  docker rm $NODE_NAME >/dev/null 2>&1 || true
fi

# Build docker command
DOCKER_CMD="docker run -d --name $NODE_NAME --network $DOCKER_NETWORK_NAME --ip $NODE_IP"

# Add port mapping if specified
[ -n "$HTTP_PORT" ] && DOCKER_CMD="$DOCKER_CMD -p ${HTTP_PORT}:3500"

# Add volumes
DOCKER_CMD="$DOCKER_CMD -v $BEACON_DIR:/data -v $CONFIG_DIR:/config"

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
DOCKER_CMD="$DOCKER_CMD --enr-address=$NODE_IP"
DOCKER_CMD="$DOCKER_CMD --listen-address=$NODE_IP"
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
log_info "IP: $NODE_IP"
[ -n "$HTTP_PORT" ] && log_info "HTTP API: http://localhost:${HTTP_PORT}"

log_info "Done!"

