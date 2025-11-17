#!/bin/bash
# Stop Blockscout Explorer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

log_info "Stopping Blockscout Explorer..."

for container in pos-el-blockscout-visualizer pos-el-blockscout-postgres pos-el-blockscout pos-el-blockscout-statsdb pos-el-blockscout-stats pos-el-blockscout-frontend pos-el-blockscout-proxy; do
  if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    log_info "Stopping: $container"
    docker stop $container
  fi
done

log_info "Blockscout stopped!"

