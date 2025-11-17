#!/bin/bash
# Batch deposit script - processes all deposits from deposit.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

RPC_URL="${1:-http://localhost:8545}"

log_info "Running batch deposits"
log_info "RPC URL: $RPC_URL"

# Run the original deposit script which contains all deposit data
bash "$ROOT_DIR/deposit.sh"

log_info "All deposits completed!"

