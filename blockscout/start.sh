#!/bin/bash
source $(pwd)/config.sh

# # Create keystore
# mkdir -p $(pwd)/blockscout/.ethereum

# # Init node
# docker run --rm \
# -v $(pwd)/blockscout/.ethereum:/.ethereum \
# -v $(pwd)/el/geth/genesis.json:/.genesis.json \
# ethereum/client-go:v1.11.6 \
# --datadir /.ethereum \
# init /.genesis.json

# # Run node
# docker run -d \
#   --name pos-el-blockscout-archive-node \
#   --network $DOCKER_NETWORK_NAME \
#   -v $(pwd)/blockscout/.ethereum:/.ethereum \
#   ethereum/client-go:v1.11.6 \
#   --http \
#   --bootnodes=$BOOT_NODE \
#   --http.api=eth,net,web3,debug,trace \
#   --http.addr=0.0.0.0 \
#   --http.corsdomain=* \
#   --http.vhosts=* \
#   --datadir=/.ethereum \
#   --networkid=1337 \
#   --authrpc.vhosts=* \
#   --authrpc.addr=0.0.0.0 \
#   --authrpc.jwtsecret=/.ethereum/jwtsecret \
#   --syncmode=full \
#   --gcmode=archive

# Run blockscout

#
# Login to Docker
#
echo 'Login to Docker..'
docker login -u bccloud -p bell*deek5cell8PSUF
echo 'Done.'

#
# Start smart contract visualizer service
#
docker run --name=pos-el-blockscout-visualizer --network $DOCKER_NETWORK_NAME --restart="unless-stopped" -d gulabs/gu-blockscout-visualizer:v0.2.0-gubuild.0

#
# Start postgres
#
echo 'Starting up Blockscout postgress container..'
docker run --name=pos-el-blockscout-postgres --network $DOCKER_NETWORK_NAME -d -e POSTGRES_HOST_AUTH_METHOD=trust --restart="unless-stopped" postgres:15 -c 'max_connections=200' -c 'client_connection_check_interval=60000'
echo 'Done..'

#
# Use wait4x for wait postgres ready on 5432
#
docker run --rm --network $DOCKER_NETWORK_NAME atkrad/wait4x:2.9.1 -q tcp "postgresql://postgres:@pos-el-blockscout-postgres:5432" && echo "Postgress is available on port 5432" || echo "Postgress is not available" 1>&2

#
# Start Blockscout
#
echo 'Starting up Blockscout container..'

# Initialize Database for Blockscout
docker run --rm --network $DOCKER_NETWORK_NAME \
-e ECTO_USE_SSL=false \
-e DATABASE_URL=postgresql://postgres:@pos-el-blockscout-postgres:5432/explorer?ssl=false \
-e ETHEREUM_JSONRPC_VARIANT=geth \
-e ETHEREUM_JSONRPC_HTTP_URL=http://172.17.0.1:8545   gulabs/gu-blockscout:v6.10.2-gubuild.0 /bin/sh -c 'bin/blockscout eval "Elixir.Explorer.ReleaseTasks.create_and_migrate()"'

# Start Blockscout
docker run --name=pos-el-blockscout --network $DOCKER_NETWORK_NAME --restart="unless-stopped"  -d \
-e PORT=9000 \
-e ECTO_USE_SSL=false \
-e SUBNETWORK=Block \
-e NETWORK=  \
-e API_V2_ENABLED=true \
-e DATABASE_URL=postgresql://postgres:@pos-el-blockscout-postgres:5432/explorer?ssl=false \
-e ETHEREUM_JSONRPC_VARIANT=geth \
-e ETHEREUM_JSONRPC_HTTP_URL=http://172.17.0.1:8545 \
-e ETHEREUM_JSONRPC_TRACE_URL=http://172.17.0.1:8545 \
-e SECRET_KEY_BASE="$(openssl rand -hex 64)" \
-e DISABLE_EXCHANGE_RATES=true \
-e MICROSERVICE_SC_VERIFIER_ENABLED=true \
-e RE_CAPTCHA_SECRET_KEY=6Le9sjcrAAAAANIeXOeiUHYZI3sT_V9O0ld9Xb5R \
-e RE_CAPTCHA_CLIENT_KEY=6Le9sjcrAAAAAJOom_4JQRBNe9_nVfPuKCp7wq6J \
-e RE_CAPTCHA_CHECK_HOSTNAME=false \
-e MICROSERVICE_SC_VERIFIER_TYPE=eth_bytecode_db \
-e RE_CAPTCHA_GUIDELINE_URL= \
-e COIN_NAME=ETH \
-e SOLIDITYSCAN_CHAIN_ID=undefined \
-e SOLIDITYSCAN_API_TOKEN= \
-e MICROSERVICE_VISUALIZE_SOL2UML_ENABLED=true \
-e MICROSERVICE_VISUALIZE_SOL2UML_URL=http://visualizer:8050   gulabs/gu-blockscout:v6.10.2-gubuild.0 /bin/sh -c "bin/blockscout start"
echo 'Done..'


#
# Start stats db
#
docker run --name=pos-el-blockscout-statsdb --network $DOCKER_NETWORK_NAME -d \
-e POSTGRES_HOST_AUTH_METHOD=trust --restart="unless-stopped" postgres:15 -c 'max_connections=200'

#
# Start blockscout stats service
#
docker run --name=pos-el-blockscout-stats --network $DOCKER_NETWORK_NAME --restart="unless-stopped" -d \
-e STATS__DB_URL="postgresql://postgres:@pos-el-blockscout-statsdb:5432/stats?ssl=false" \
-e STATS__BLOCKSCOUT_DB_URL="postgresql://postgres:@pos-el-blockscout-postgres:5432/explorer?ssl=false" \
-e STATS__CREATE_DATABASE=true \
-e STATS__RUN_MIGRATIONS=true gulabs/gu-blockscout-stats:v1.5.2-gubuild.0

#
# Start Blockscout FE
#

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
APP_IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
echo "APP_IP_ADDRESS: $APP_IP_ADDRESS"

docker run --name=pos-el-blockscout-frontend --network $DOCKER_NETWORK_NAME --restart="unless-stopped" -d \
-e NEXT_PUBLIC_NETWORK_ID=1337 \
-e NEXT_PUBLIC_NETWORK_NAME="pos-devnet" \
-e NEXT_PUBLIC_RE_CAPTCHA_APP_SITE_KEY="6Le9sjcrAAAAAJOom_4JQRBNe9_nVfPuKCp7wq6J" \
-e NEXT_PUBLIC_AD_BANNER_PROVIDER=none \
-e NEXT_PUBLIC_AD_TEXT_PROVIDER=none \
-e NEXT_PUBLIC_HOMEPAGE_CHARTS="['daily_txs']" \
-e NEXT_PUBLIC_GAS_TRACKER_UNITS="['gwei']" \
-e NEXT_PUBLIC_NETWORK_CURRENCY_NAME="Ether" \
-e NEXT_PUBLIC_NETWORK_CURRENCY_SYMBOL="ETH" \
-e NEXT_PUBLIC_APP_PROTOCOL="http" \
-e NEXT_PUBLIC_API_PROTOCOL="http" \
-e NEXT_PUBLIC_API_HOST="$APP_IP_ADDRESS:9000" \
-e NEXT_PUBLIC_APP_HOST="$APP_IP_ADDRESS:9000" \
-e NEXT_PUBLIC_VISUALIZE_API_HOST="http://$APP_IP_ADDRESS:9000" \
-e NEXT_PUBLIC_VISUALIZE_API_BASE_PATH="/services/visualizer" \
-e NEXT_PUBLIC_STATS_API_HOST="http://$APP_IP_ADDRESS:9000" \
-e NEXT_PUBLIC_STATS_API_BASE_PATH="/services/stats" \
-e NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID="b293113c137b441c430d854b321888f6" \
-e NEXT_PUBLIC_NETWORK_RPC_URL="http://$APP_IP_ADDRESS:8545/" \
-e NEXT_PUBLIC_VIEWS_CONTRACT_SOLIDITYSCAN_ENABLED=false \
gulabs/gu-blockscout-frontend:v1.37.5-gubuild.0

# Config Proxy
docker run -d --name pos-el-blockscout-proxy --restart="unless-stopped" --network $DOCKER_NETWORK_NAME -v "$(pwd)/blockscout/proxy:/etc/nginx/templates" \
-e BACK_PROXY_PASS="${BACK_PROXY_PASS:-http://pos-el-blockscout:9000}" \
-e FRONT_PROXY_PASS="${FRONT_PROXY_PASS:-http://pos-el-blockscout-frontend:3000}" \
-e STATS_PROXY_PASS="${STATS_PROXY_PASS:-http://pos-el-blockscout-stats:8050}" \
-e VISUALIZER_PROXY_PASS="${VISUALIZER_PROXY_PASS:-http://pos-el-blockscout-visualizer:8050}" -p 9000:80 nginx:1.25
