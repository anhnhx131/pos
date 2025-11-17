#!/bin/bash
# Make validator deposits to the deposit contract

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --private-key <key>           Private key to send deposit from"
  echo "  --pubkey <key>                Validator public key"
  echo "  --withdrawal-credentials <c>  Withdrawal credentials"
  echo "  --signature <sig>             Deposit signature"
  echo "  --deposit-data-root <root>    Deposit data root"
  echo "  --rpc-url <url>               Ethereum RPC URL (default: http://localhost:8545)"
  echo "  --use-script                  Use the TypeScript deposit script"
  exit 1
}

PRIVATE_KEY=""
PUBKEY=""
WITHDRAWAL_CREDENTIALS=""
SIGNATURE=""
DEPOSIT_DATA_ROOT=""
RPC_URL="http://localhost:8545"
USE_SCRIPT=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --private-key)
      PRIVATE_KEY="$2"
      shift 2
      ;;
    --pubkey)
      PUBKEY="$2"
      shift 2
      ;;
    --withdrawal-credentials)
      WITHDRAWAL_CREDENTIALS="$2"
      shift 2
      ;;
    --signature)
      SIGNATURE="$2"
      shift 2
      ;;
    --deposit-data-root)
      DEPOSIT_DATA_ROOT="$2"
      shift 2
      ;;
    --rpc-url)
      RPC_URL="$2"
      shift 2
      ;;
    --use-script)
      USE_SCRIPT=true
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

if [ "$USE_SCRIPT" = true ]; then
  log_info "Using TypeScript deposit script"
  cd "$ROOT_DIR/interact-eth1/deposit"
  
  if [ ! -d "node_modules" ]; then
    log_info "Installing dependencies..."
    npm install
  fi
  
  log_info "Running deposit script..."
  npm run deposit
else
  # Validate required arguments for manual deposit
  if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBKEY" ] || [ -z "$WITHDRAWAL_CREDENTIALS" ] || \
     [ -z "$SIGNATURE" ] || [ -z "$DEPOSIT_DATA_ROOT" ]; then
    log_error "All deposit parameters are required for manual deposit"
    usage
  fi

  log_info "Making validator deposit"
  log_info "  PubKey: $PUBKEY"
  log_info "  RPC URL: $RPC_URL"

  # Use the CLI deposit script
  export PRIVATE_KEY="$PRIVATE_KEY"
  export PUBKEY="$PUBKEY"
  export WITHDRAWAL_CREDENTIALS="$WITHDRAWAL_CREDENTIALS"
  export SIGNATURE="$SIGNATURE"
  export DEPOSIT_DATA_ROOT="$DEPOSIT_DATA_ROOT"
  export RPC_URL="$RPC_URL"
  
  bash "$ROOT_DIR/interact-eth1/cli/deposit.sh"
fi

log_info "Deposit completed successfully!"

