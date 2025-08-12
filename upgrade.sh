#!/bin/bash
source $(pwd)/config.sh

# Run miner node
echo "Read shanghai time..."
BEACON=http://localhost:3500
EPOCH=10

# Lấy thông tin genesis
GENESIS_TIME=$(curl -s $BEACON/eth/v1/beacon/genesis | jq -r '.data.genesis_time')

# Lấy spec
SECONDS_PER_SLOT=$(curl -s $BEACON/eth/v1/config/spec | jq -r '.data.seconds_per_slot')
SLOTS_PER_EPOCH=$(curl -s $BEACON/eth/v1/config/spec | jq -r '.data.slots_per_epoch')

# Tính timestamp epoch
SLOTS_TOTAL=$(( EPOCH * SLOTS_PER_EPOCH ))
TIMESTAMP=$(( GENESIS_TIME + SLOTS_TOTAL * SECONDS_PER_SLOT ))

echo "Timestamp: $TIMESTAMP"

echo "Update genesis.json..."
sed -i "s/\"shanghaiTime\": [0-9]*/\"shanghaiTime\": $TIMESTAMP/g" el/geth/genesis.json

echo "Init geth"
# Start additional nodes dynamically
for (( i=0; i<$NUM_NODES; i++ )); do
  EL_NODE_NAME="pos_node$i-el"
  # stop docker
  docker stop $EL_NODE_NAME

  # Init node
  docker run --rm \
    -v $(pwd)/el/geth/.ethereum-$i:/.ethereum \
    -v $(pwd)/el/geth/genesis.json:/.genesis.json \
    ethereum/client-go:v1.11.5 \
    --datadir /.ethereum \
    init /.genesis.json

  # Run geth node
  docker restart $EL_NODE_NAME

  sleep 3

done
