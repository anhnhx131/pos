#!/bin/bash
source $(pwd)/config.sh

# Run miner node
echo "Read shanghai time..."
BEACON=http://localhost:3500
EPOCH=10

# Lấy thông tin genesis
GENESIS_TIME=$(curl -s $BEACON/eth/v1/beacon/genesis | jq -r '.data.genesis_time')

# Lấy spec
SECONDS_PER_SLOT=$(curl -s $BEACON/eth/v1/config/spec | jq -r '.data.SECONDS_PER_SLOT')
SLOTS_PER_EPOCH=$(curl -s $BEACON/eth/v1/config/spec | jq -r '.data.SLOTS_PER_EPOCH')

echo "Seconds per slot: $SECONDS_PER_SLOT"
echo "Slots per epoch: $SLOTS_PER_EPOCH"

echo "Genesis time: $GENESIS_TIME"

# Tính timestamp epoch
SLOTS_TOTAL=$(( EPOCH * SLOTS_PER_EPOCH ))
TIMESTAMP=$(( GENESIS_TIME + SLOTS_TOTAL * SECONDS_PER_SLOT ))

echo "Timestamp: $TIMESTAMP"

echo "Update genesis.json..."
sed -i "s/\"cancunTime\": [0-9]*/\"cancunTime\": $TIMESTAMP/g" el/geth/genesis.json

echo "Init geth"
# Start additional nodes dynamically
for (( i=0; i<$NUM_NODES; i++ )); do
  EL_NODE_IP="10.7.1.$((i+BOOT_NODES+2))"
  EL_NODE_NAME="pos_node$i-el"
  # stop docker
  docker stop -t 300 $EL_NODE_NAME
  docker rm -f $EL_NODE_NAME

  # Init node
  docker run --rm \
    -v $(pwd)/el/geth/.ethereum-$i:/.ethereum \
    -v $(pwd)/el/geth/genesis.json:/.genesis.json \
    ethereum/client-go:v1.13.14 \
    --datadir /.ethereum \
    init /.genesis.json

  # # Run geth node
  # docker restart $EL_NODE_NAME

  # Run geth node
  docker run -d \
    --name $EL_NODE_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $EL_NODE_IP \
    $( [ "$i" -eq 0 ] && echo "-p 8545:8545" ) \
    -v $(pwd)/el/geth/.ethereum-$i:/.ethereum \
    ethereum/client-go:v1.13.14 \
    --nat=extip:$EL_NODE_IP \
    --http \
    --bootnodes=$BOOT_NODE \
    --http.api=eth,net,web3,debug,trace,engine,admin \
    --http.addr=0.0.0.0 \
    --http.corsdomain=* \
    --http.vhosts=* \
    --datadir=/.ethereum \
    --networkid=84 \
    --authrpc.vhosts=* \
    --authrpc.addr=0.0.0.0 \
    --authrpc.jwtsecret=/.ethereum/jwtsecret \
    --syncmode=full \
    --rpc.allow-unprotected-txs \
    $([ "$i" -eq 0 ] && echo "--nodekey /.ethereum/boot.key" || echo "")

  sleep 3

done
