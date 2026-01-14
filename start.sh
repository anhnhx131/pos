#!/bin/bash
source $(pwd)/config.sh

VALDAITOR_KEY_PASSWORD="password123456"

SUBNET=10.7.0.0/16

# Create docker network if not exists
if ! docker network inspect $DOCKER_NETWORK_NAME >/dev/null 2>&1; then
  docker network create $DOCKER_NETWORK_NAME --driver bridge --subnet $SUBNET
fi

# Run bootnode
for (( i=0; i<$BOOT_NODES; i++ )); do
  BOOT_NODE_IP="10.7.2.$((i+2))"
  BOOT_NODE_NAME="pos_bootnode$i"

  docker run -d \
    --name $BOOT_NODE_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $BOOT_NODE_IP \
    -v $(pwd)/cl/bn$i:/data \
    -v $(pwd)/cl/config:/config \
    sigp/lighthouse:v7.0.1 \
    lighthouse \
    boot_node \
    --datadir=/data \
    --testnet-dir=/config \
    --disable-packet-filter \
    --enable-enr-auto-update \
    --listen-address=$BOOT_NODE_IP \
    --enr-address=$BOOT_NODE_IP
done

# Start clique node
EL_NODE_IP="10.7.1.$((BOOT_NODES+2))"
EL_NODE_NAME="pos_clique_node-el"
EL_NODE_PRIVATE_KEY=$(echo ${MINER_NODES[0]} | jq -r .private_key)
EL_NODE_PUBLIC_KEY=$(echo ${MINER_NODES[0]} | jq -r .public_key)

# define geth data dir
mkdir -p $(pwd)/el/geth/.ethereum

echo $POA_BOOT_NODE_KEY > $(pwd)/el/geth/.ethereum/boot.key

# Create keystore
echo $EL_NODE_PRIVATE_KEY > $(pwd)/el/geth/.ethereum/private.key
echo "password" > $(pwd)/el/geth/.ethereum/password.txt

docker run --rm \
  -v $(pwd)/el/geth/.ethereum:/.ethereum \
  ethereum/client-go:v1.11.5 \
  account import --datadir /.ethereum --password /.ethereum/password.txt /.ethereum/private.key

# Init node
docker run --rm \
  -v $(pwd)/el/geth/.ethereum:/.ethereum \
  -v $(pwd)/el/geth/poa.json:/.genesis.json \
  ethereum/client-go:v1.11.5 \
  --datadir /.ethereum init /.genesis.json

# Run geth node
docker run -d \
  --name $EL_NODE_NAME \
  --network $DOCKER_NETWORK_NAME \
  --ip $EL_NODE_IP \
  -v $(pwd)/el/geth/.ethereum:/.ethereum \
  ethereum/client-go:v1.11.5 \
  --nat=extip:$EL_NODE_IP \
  --http \
  --http.api=eth,net,web3,debug,debug,engine,admin \
  --http.addr=0.0.0.0 \
  --http.corsdomain=* \
  --http.vhosts=* \
  --datadir=/.ethereum \
  --allow-insecure-unlock \
  --unlock=$EL_NODE_PUBLIC_KEY \
  --miner.etherbase=$EL_NODE_PUBLIC_KEY \
  --mine \
  --networkid=84 \
  --syncmode=full \
  --password=/.ethereum/password.txt \
  --rpc.allow-unprotected-txs \
  --nodekey /.ethereum/boot.key

# Run normal node
for (( i=0; i<$NORMAL_NODES; i++ )); do
  EL_NODE_IP="10.7.1.$((i+BOOT_NODES+3))"
  EL_NODE_NAME="pos_normal_node$i-el"
  # beacon node
  BEACON_NODE_IP="10.7.2.$((i+BOOT_NODES+2))"
  BEACON_NODE_NAME="pos_normal_node$i-beacon"

  # define geth data dir
  mkdir -p $(pwd)/el/geth/.ethereum-$i
  echo $JWT_SECRET > $(pwd)/el/geth/.ethereum-$i/jwtsecret

  if [ "$i" -eq 0 ]; then
    echo $BOOT_NODE_KEY > $(pwd)/el/geth/.ethereum-$i/boot.key
  fi

  # Init node
  docker run --rm \
    -v $(pwd)/el/geth/.ethereum-$i:/.ethereum \
    -v $(pwd)/el/geth/genesis.json:/.genesis.json \
    ethereum/client-go:v1.11.5 \
    --datadir /.ethereum init /.genesis.json

  # Run geth node
  docker run -d \
    --name $EL_NODE_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $EL_NODE_IP \
    $( [ "$i" -eq 1 ] && echo "-p 8545:8545" ) \
    -v $(pwd)/el/geth/.ethereum-$i:/.ethereum \
    ethereum/client-go:v1.11.5 \
    --nat=extip:$EL_NODE_IP \
    --http \
    --bootnodes=$BOOT_NODE,$POS_EL_BOOT_NODE \
    --http.api=eth,net,web3,debug,debug,engine,admin \
    --http.addr=0.0.0.0 \
    --http.corsdomain=* \
    --http.vhosts=* \
    --datadir=/.ethereum \
    --allow-insecure-unlock \
    --networkid=84 \
    --authrpc.vhosts=* \
    --authrpc.addr=0.0.0.0 \
    --authrpc.jwtsecret=/.ethereum/jwtsecret \
    --syncmode=full \
    --password=/.ethereum/password.txt \
    --rpc.allow-unprotected-txs \
    $([ "$i" -eq 0 ] && echo "--nodekey /.ethereum/boot.key" || echo "")

  # Run beacon node
  docker run -d \
    --name $BEACON_NODE_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $BEACON_NODE_IP \
    -p 350$i:3500 \
    -v $(pwd)/cl/config:/config \
    sigp/lighthouse:v7.0.1 \
    lighthouse \
    beacon_node \
    --datadir=/data \
    --eth1 \
    --http \
    --http-address=0.0.0.0 \
    --http-port=3500 \
    --http-allow-origin=* \
    --execution-endpoint=http://$EL_NODE_IP:8551 \
    --execution-jwt=/config/jwtsecret \
    --testnet-dir=/config \
    --boot-nodes=enr:-IS4QPOOGJE5V8GmhjshFUZ0pHWWWV008jgMGH3reH3HMtoEIR8UPrnl4OQO4xNSuwAtcgL6Omf4YPqi0zxMYO1GevUBgmlkgnY0gmlwhAoHAgKJc2VjcDI1NmsxoQOIhz10UYFO65iCNMMmcXHJQmk2FRNrqm0KoNtpBCicpoN1ZHCCIyg,enr:-IS4QATvRDQtMnslfe2DDfQ9au3gvF0oD9yrUswhLMWycafWPLOU9ZjXG0L0m9RJq-7V3lFhKXm9nVslPfizMgvfQZsBgmlkgnY0gmlwhAoHAgOJc2VjcDI1NmsxoQLh78RCFhcrgZ5tKgayyL9TTVXnK8mIlzBZoWiYQqdlUoN1ZHCCIyg \
    --disable-upnp \
    --enr-address=$BEACON_NODE_IP \
    --listen-address=$BEACON_NODE_IP \
    --enr-tcp-port=9000 \
    --enr-udp-port=9000 \
    --gui \
    --enable-private-discovery
done

# Start validators nodes dynamically
for (( i=0; i<$VALIDATOR_NODES; i++ )); do
  EL_NODE_IP="10.7.1.$((NORMAL_NODES+i+BOOT_NODES+3))"
  EL_NODE_NAME="pos_validator_node$i-el"
  # beacon node
  BEACON_NODE_IP="10.7.2.$((NORMAL_NODES+i+BOOT_NODES+2))"
  BEACON_NODE_NAME="pos_validator_node$i-beacon"
  # validator
  VALIDATOR_NODE_IP="10.7.3.$((NORMAL_NODES+i+BOOT_NODES+2))"
  VALIDATOR_NODE_NAME="pos_validator_node$i-validator"
  VALIDATOR_API_TOKEN=R6YhbDO6gKjNMydtZHcaCovFbQ0izq5Hk

  # define geth data dir
  mkdir -p $(pwd)/el/geth/.ethereum-val-$i
  echo $JWT_SECRET > $(pwd)/el/geth/.ethereum-val-$i/jwtsecret

  # Init node
  docker run --rm \
    -v $(pwd)/el/geth/.ethereum-val-$i:/.ethereum \
    -v $(pwd)/el/geth/genesis.json:/.genesis.json \
    ethereum/client-go:v1.11.5 \
    --datadir /.ethereum init /.genesis.json

  # Run geth node
  docker run -d \
    --name $EL_NODE_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $EL_NODE_IP \
    -v $(pwd)/el/geth/.ethereum-val-$i:/.ethereum \
    $( [ "$i" -eq 0 ] && echo "-p 8546:8545" ) \
    ethereum/client-go:v1.11.5 \
    --nat=extip:$EL_NODE_IP \
    --http \
    --bootnodes=$POS_EL_BOOT_NODE,$BOOT_NODE \
    --http.api=eth,net,web3,debug,debug,engine,admin \
    --http.addr=0.0.0.0 \
    --http.corsdomain=* \
    --http.vhosts=* \
    --datadir=/.ethereum \
    --allow-insecure-unlock \
    --networkid=84 \
    --authrpc.vhosts=* \
    --authrpc.addr=0.0.0.0 \
    --authrpc.jwtsecret=/.ethereum/jwtsecret \
    --syncmode=full \
    --password=/.ethereum/password.txt \
    --rpc.allow-unprotected-txs

  # Run beacon node
  docker run -d \
    --name $BEACON_NODE_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $BEACON_NODE_IP \
    $( [ "$i" -eq 0 ] && echo "-p 3505:3500" ) \
    -v $(pwd)/cl/config:/config \
    sigp/lighthouse:v7.0.1 \
    lighthouse \
    beacon_node \
    --datadir=/data \
    --eth1 \
    --http \
    --http-address=0.0.0.0 \
    --http-port=3500 \
    --http-allow-origin=* \
    --execution-endpoint=http://$EL_NODE_IP:8551 \
    --execution-jwt=/config/jwtsecret \
    --testnet-dir=/config \
    --boot-nodes=enr:-IS4QPOOGJE5V8GmhjshFUZ0pHWWWV008jgMGH3reH3HMtoEIR8UPrnl4OQO4xNSuwAtcgL6Omf4YPqi0zxMYO1GevUBgmlkgnY0gmlwhAoHAgKJc2VjcDI1NmsxoQOIhz10UYFO65iCNMMmcXHJQmk2FRNrqm0KoNtpBCicpoN1ZHCCIyg,enr:-IS4QATvRDQtMnslfe2DDfQ9au3gvF0oD9yrUswhLMWycafWPLOU9ZjXG0L0m9RJq-7V3lFhKXm9nVslPfizMgvfQZsBgmlkgnY0gmlwhAoHAgOJc2VjcDI1NmsxoQLh78RCFhcrgZ5tKgayyL9TTVXnK8mIlzBZoWiYQqdlUoN1ZHCCIyg \
    --disable-upnp \
    --enr-address=$BEACON_NODE_IP \
    --listen-address=$BEACON_NODE_IP \
    --enr-tcp-port=9000 \
    --enr-udp-port=9000 \
    --gui \
    --enable-private-discovery
    # --debug-level=debug \

  # Run validator node
  # create key
  mkdir -p $(pwd)/cl/validator-$i
  mkdir -p $(pwd)/cl/validator-$i/validators
  mkdir -p $(pwd)/cl/validator-$i/validator_keys
  echo ${BEACON_VALIDATORS[$i]} > $(pwd)/cl/validator-$i/validator_keys/keystore-m_12381_3600_1_0_0-$(date +%s).json
  echo $VALDAITOR_KEY_PASSWORD > $(pwd)/cl/validator-$i/validator_keys/password.txt
  printf $VALIDATOR_API_TOKEN > $(pwd)/cl/validator-$i/validators/api-token.txt

  # import keystore
  docker run --rm \
    -v $(pwd)/cl/validator-$i:/data \
    -v $(pwd)/cl/config:/config \
    sigp/lighthouse:v7.0.1 \
    lighthouse \
    account_manager \
    validator \
    import \
    --datadir=/data \
    --directory=/data/validator_keys \
    --password-file=/data/validator_keys/password.txt \
    --testnet-dir=/config \
    --reuse-password

  # run validator client
  docker run -d \
    --name $VALIDATOR_NODE_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $VALIDATOR_NODE_IP \
    -v $(pwd)/cl/validator-$i:/data \
    -v $(pwd)/cl/config:/config \
    sigp/lighthouse:v7.0.1 \
    lighthouse \
    validator_client \
    --validators-dir=/data/validators \
    --testnet-dir=/config \
    --beacon-nodes=http://$BEACON_NODE_IP:3500 \
    --http \
    --http-address=0.0.0.0 \
    --unencrypted-http-transport \
    --http-port=5062 \
    --http-allow-origin=* \
    --suggested-fee-recipient=0x23081455D3FEaf17426176dfc5Ee7A3ce519aD33

  # Run siren UI
#   mkdir -p $(pwd)/cl/validator-$i/siren
#   cat > $(pwd)/cl/validator-$i/siren/.env << EOF
# BEACON_URL=http://$BEACON_NODE_IP:3500
# VALIDATOR_URL=http://$VALIDATOR_NODE_IP:5062
# API_TOKEN=$VALIDATOR_API_TOKEN
# SESSION_PASSWORD=password
# SSL_ENABLED=false
# DEBUG=false
# # don't change these when building the docker image, only change when running outside of docker
# PORT=3000
# BACKEND_URL=http://127.0.0.1:3001
# # if BACKEND_URL is changed, BACKEND_PORT must have a matching port
# BACKEND_PORT=3001
# EOF

#   docker run -d \
#     --network $DOCKER_NETWORK_NAME \
#     --name pos_siren-$i \
#     --restart=unless-stopped \
#     -p 344$i:80 \
#     --env-file $(pwd)/cl/validator-$i/siren/.env \
#     sigp/siren
done

# deposit
sleep 10
sh deposit.sh

# Run dora explorer
sh dora/start.sh

# Run blockscout
# sh blockscout/start.sh
