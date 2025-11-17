#!/bin/bash
# Stop a Lighthouse node (bootnode, beacon, or validator)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

NODE_NAME="${1}"

if [ -z "$NODE_NAME" ]; then
  log_error "Usage: $0 <node_name>"
  exit 1
fi

log_info "Stopping Lighthouse node: $NODE_NAME"

if docker ps --format '{{.Names}}' | grep -q "^${NODE_NAME}$"; then
  docker stop $NODE_NAME
  log_info "Node stopped successfully"
else
  log_warn "Node $NODE_NAME is not running"
fi

