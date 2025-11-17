#!/bin/bash
# Stop Dora Explorer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

log_info "Stopping Dora Explorer..."

if docker ps --format '{{.Names}}' | grep -q "^pos-dora$"; then
  docker stop pos-dora
  log_info "Dora stopped!"
else
  log_warn "Dora is not running"
fi

