#!/bin/bash
# Stop all network components

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

log_info "Stopping all network components..."

# Stop all containers with our naming convention
log_info "Stopping Geth nodes..."
docker ps -a --filter "name=geth-" --format "{{.Names}}" | xargs -r docker stop

log_info "Stopping Lighthouse nodes..."
docker ps -a --filter "name=lighthouse-" --format "{{.Names}}" | xargs -r docker stop

log_info "Stopping Blockscout..."
bash "$SCRIPT_DIR/modules/blockscout/stop.sh" 2>/dev/null || true

log_info "Stopping Dora..."
bash "$SCRIPT_DIR/modules/dora/stop.sh" 2>/dev/null || true

log_info "All components stopped!"

