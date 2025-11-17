#!/bin/bash
# Start Blockscout Explorer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/config.sh"

# Parse arguments
usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --rpc-url <url>          Geth RPC URL (default: http://172.17.0.1:8545)"
  echo "  --port <port>            Blockscout port (default: 9000)"
  echo "  --network-name <name>    Network display name (default: pos-devnet)"
  echo "  --network-id <id>        Network ID (default: from config)"
  exit 1
}

RPC_URL="${RPC_URL:-http://172.17.0.1:8545}"
PORT="${BLOCKSCOUT_PORT}"
NETWORK_NAME="pos-devnet"
NETWORK_ID="$NETWORK_ID"

while [[ $# -gt 0 ]]; do
  case $1 in
    --rpc-url)
      RPC_URL="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --network-name)
      NETWORK_NAME="$2"
      shift 2
      ;;
    --network-id)
      NETWORK_ID="$2"
      shift 2
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

log_info "Starting Blockscout Explorer"
log_info "  RPC URL: $RPC_URL"
log_info "  Port: $PORT"
log_info "  Network: $NETWORK_NAME (ID: $NETWORK_ID)"

# Create network if not exists
create_docker_network

# Login to Docker
log_info "Logging in to Docker..."
docker login -u "$BLOCKSCOUT_DOCKER_USERNAME" -p "$BLOCKSCOUT_DOCKER_PASSWORD" 2>/dev/null || log_warn "Docker login failed, continuing..."

# Stop existing containers if running
for container in pos-el-blockscout-visualizer pos-el-blockscout-postgres pos-el-blockscout pos-el-blockscout-statsdb pos-el-blockscout-stats pos-el-blockscout-frontend pos-el-blockscout-proxy; do
  if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
    log_info "Stopping existing container: $container"
    docker stop $container >/dev/null 2>&1 || true
    docker rm $container >/dev/null 2>&1 || true
  fi
done

# Start smart contract visualizer service
log_info "Starting visualizer..."
docker run --name=pos-el-blockscout-visualizer \
  --network $DOCKER_NETWORK_NAME \
  --restart="unless-stopped" -d \
  gulabs/gu-blockscout-visualizer:v0.2.0-gubuild.0

# Start postgres
log_info "Starting PostgreSQL..."
docker run --name=pos-el-blockscout-postgres \
  --network $DOCKER_NETWORK_NAME -d \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  --restart="unless-stopped" \
  postgres:15 -c 'max_connections=200' -c 'client_connection_check_interval=60000'

# Wait for postgres
log_info "Waiting for PostgreSQL to be ready..."
sleep 5
docker run --rm --network $DOCKER_NETWORK_NAME atkrad/wait4x:2.9.1 -q tcp "postgresql://postgres:@pos-el-blockscout-postgres:5432" && \
  log_info "PostgreSQL is ready" || log_error "PostgreSQL startup timeout"

# Initialize Database for Blockscout
log_info "Initializing Blockscout database..."
docker run --rm --network $DOCKER_NETWORK_NAME \
  -e ECTO_USE_SSL=false \
  -e DATABASE_URL=postgresql://postgres:@pos-el-blockscout-postgres:5432/explorer?ssl=false \
  -e ETHEREUM_JSONRPC_VARIANT=geth \
  -e ETHEREUM_JSONRPC_HTTP_URL="$RPC_URL" \
  gulabs/gu-blockscout:v6.10.2-gubuild.0 \
  /bin/sh -c 'bin/blockscout eval "Elixir.Explorer.ReleaseTasks.create_and_migrate()"'

# Start Blockscout
log_info "Starting Blockscout backend..."
docker run --name=pos-el-blockscout \
  --network $DOCKER_NETWORK_NAME \
  --restart="unless-stopped" -d \
  -e PORT=$PORT \
  -e ECTO_USE_SSL=false \
  -e SUBNETWORK=Block \
  -e NETWORK="" \
  -e API_V2_ENABLED=true \
  -e DATABASE_URL=postgresql://postgres:@pos-el-blockscout-postgres:5432/explorer?ssl=false \
  -e ETHEREUM_JSONRPC_VARIANT=geth \
  -e ETHEREUM_JSONRPC_HTTP_URL="$RPC_URL" \
  -e ETHEREUM_JSONRPC_TRACE_URL="$RPC_URL" \
  -e SECRET_KEY_BASE="$(openssl rand -hex 64)" \
  -e DISABLE_EXCHANGE_RATES=true \
  -e MICROSERVICE_SC_VERIFIER_ENABLED=true \
  -e RE_CAPTCHA_SECRET_KEY=6Le9sjcrAAAAANIeXOeiUHYZI3sT_V9O0ld9Xb5R \
  -e RE_CAPTCHA_CLIENT_KEY=6Le9sjcrAAAAAJOom_4JQRBNe9_nVfPuKCp7wq6J \
  -e RE_CAPTCHA_CHECK_HOSTNAME=false \
  -e MICROSERVICE_SC_VERIFIER_TYPE=eth_bytecode_db \
  -e RE_CAPTCHA_GUIDELINE_URL="" \
  -e COIN_NAME=ETH \
  -e SOLIDITYSCAN_CHAIN_ID=undefined \
  -e SOLIDITYSCAN_API_TOKEN="" \
  -e MICROSERVICE_VISUALIZE_SOL2UML_ENABLED=true \
  -e MICROSERVICE_VISUALIZE_SOL2UML_URL=http://pos-el-blockscout-visualizer:8050 \
  gulabs/gu-blockscout:v6.10.2-gubuild.0 \
  /bin/sh -c "bin/blockscout start"

# Start stats db
log_info "Starting stats database..."
docker run --name=pos-el-blockscout-statsdb \
  --network $DOCKER_NETWORK_NAME -d \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  --restart="unless-stopped" \
  postgres:15 -c 'max_connections=200'

# Start blockscout stats service
log_info "Starting stats service..."
docker run --name=pos-el-blockscout-stats \
  --network $DOCKER_NETWORK_NAME \
  --restart="unless-stopped" -d \
  -e STATS__DB_URL="postgresql://postgres:@pos-el-blockscout-statsdb:5432/stats?ssl=false" \
  -e STATS__BLOCKSCOUT_DB_URL="postgresql://postgres:@pos-el-blockscout-postgres:5432/explorer?ssl=false" \
  -e STATS__CREATE_DATABASE=true \
  -e STATS__RUN_MIGRATIONS=true \
  gulabs/gu-blockscout-stats:v1.5.2-gubuild.0

# Get public IP (try AWS metadata, fallback to localhost)
APP_IP_ADDRESS=$(curl -s -m 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" | \
  xargs -I {} curl -s -m 2 -H "X-aws-ec2-metadata-token: {}" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null) || APP_IP_ADDRESS="localhost"
log_info "Public IP: $APP_IP_ADDRESS"

# Start Blockscout frontend
log_info "Starting frontend..."
docker run --name=pos-el-blockscout-frontend \
  --network $DOCKER_NETWORK_NAME \
  --restart="unless-stopped" -d \
  -e NEXT_PUBLIC_NETWORK_ID="$NETWORK_ID" \
  -e NEXT_PUBLIC_NETWORK_NAME="$NETWORK_NAME" \
  -e NEXT_PUBLIC_RE_CAPTCHA_APP_SITE_KEY="6Le9sjcrAAAAAJOom_4JQRBNe9_nVfPuKCp7wq6J" \
  -e NEXT_PUBLIC_AD_BANNER_PROVIDER=none \
  -e NEXT_PUBLIC_AD_TEXT_PROVIDER=none \
  -e NEXT_PUBLIC_HOMEPAGE_CHARTS="['daily_txs']" \
  -e NEXT_PUBLIC_GAS_TRACKER_UNITS="['gwei']" \
  -e NEXT_PUBLIC_NETWORK_CURRENCY_NAME="Ether" \
  -e NEXT_PUBLIC_NETWORK_CURRENCY_SYMBOL="ETH" \
  -e NEXT_PUBLIC_APP_PROTOCOL="http" \
  -e NEXT_PUBLIC_API_PROTOCOL="http" \
  -e NEXT_PUBLIC_API_HOST="$APP_IP_ADDRESS:$PORT" \
  -e NEXT_PUBLIC_APP_HOST="$APP_IP_ADDRESS:$PORT" \
  -e NEXT_PUBLIC_VISUALIZE_API_HOST="http://$APP_IP_ADDRESS:$PORT" \
  -e NEXT_PUBLIC_VISUALIZE_API_BASE_PATH="/services/visualizer" \
  -e NEXT_PUBLIC_STATS_API_HOST="http://$APP_IP_ADDRESS:$PORT" \
  -e NEXT_PUBLIC_STATS_API_BASE_PATH="/services/stats" \
  -e NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID="b293113c137b441c430d854b321888f6" \
  -e NEXT_PUBLIC_NETWORK_RPC_URL="http://$APP_IP_ADDRESS:8545/" \
  -e NEXT_PUBLIC_VIEWS_CONTRACT_SOLIDITYSCAN_ENABLED=false \
  gulabs/gu-blockscout-frontend:v1.37.5-gubuild.0

# Config Proxy
log_info "Starting nginx proxy..."
docker run -d --name pos-el-blockscout-proxy \
  --restart="unless-stopped" \
  --network $DOCKER_NETWORK_NAME \
  -v "$ROOT_DIR/blockscout/proxy:/etc/nginx/templates" \
  -e BACK_PROXY_PASS="${BACK_PROXY_PASS:-http://pos-el-blockscout:$PORT}" \
  -e FRONT_PROXY_PASS="${FRONT_PROXY_PASS:-http://pos-el-blockscout-frontend:3000}" \
  -e STATS_PROXY_PASS="${STATS_PROXY_PASS:-http://pos-el-blockscout-stats:8050}" \
  -e VISUALIZER_PROXY_PASS="${VISUALIZER_PROXY_PASS:-http://pos-el-blockscout-visualizer:8050}" \
  -p $PORT:80 \
  nginx:1.25

log_info "Blockscout started successfully!"
log_info "Access at: http://$APP_IP_ADDRESS:$PORT"
log_info "Done!"

