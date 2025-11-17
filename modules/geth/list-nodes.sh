#!/bin/bash
# List all Geth nodes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

log_info "Geth Nodes:"
docker ps -a --filter "name=geth-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -n 20

