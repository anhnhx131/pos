#!/bin/bash
# Clean all network data and containers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

read -p "This will remove all containers and data. Are you sure? (yes/no) " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
  log_info "Cancelled"
  exit 0
fi

log_warn "Cleaning all network components..."

# Stop all containers first
bash "$SCRIPT_DIR/stop-network.sh"

# Remove containers
log_info "Removing Geth containers..."
docker ps -a --filter "name=geth-" --format "{{.Names}}" | xargs -r docker rm

log_info "Removing Lighthouse containers..."
docker ps -a --filter "name=lighthouse-" --format "{{.Names}}" | xargs -r docker rm

log_info "Removing Blockscout containers..."
for container in pos-el-blockscout-visualizer pos-el-blockscout-postgres pos-el-blockscout pos-el-blockscout-statsdb pos-el-blockscout-stats pos-el-blockscout-frontend pos-el-blockscout-proxy; do
  docker rm -f $container 2>/dev/null || true
done

log_info "Removing Dora container..."
docker rm -f pos-dora 2>/dev/null || true

# Optionally remove network
read -p "Remove Docker network? (yes/no) " -r
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
  log_info "Removing Docker network..."
  docker network rm $DOCKER_NETWORK_NAME 2>/dev/null || true
fi

# Optionally remove data
read -p "Remove all data directories? (yes/no) " -r
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
  log_warn "Removing data directories..."
  rm -rf "${EL_DIR}/geth/geth-"*
  rm -rf "${EL_DIR}/geth/.ethereum-"*
  rm -rf "${CL_DIR}/beacon-"*
  rm -rf "${CL_DIR}/validator-"*
  log_info "Data removed"
fi

log_info "Cleanup complete!"

