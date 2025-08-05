#!/bin/bash
source $(pwd)/config.sh

# Run miner node
echo "Update ethereum node..."

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

# Update geth blockscout
# stop docker
docker stop pos-el-blockscout-archive-node

# Init node
docker run --rm \
  -v $(pwd)/blockscout/.ethereum:/.ethereum \
  -v $(pwd)/el/geth/genesis.json:/.genesis.json \
  ethereum/client-go:v1.11.5 \
  --datadir /.ethereum \
  init /.genesis.json

# Run geth node
docker restart pos-el-blockscout-archive-node
