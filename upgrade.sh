#!/bin/bash
source $(pwd)/config.sh

# Run miner node
echo "Update ethereum node..."

# Start additional nodes dynamically
for (( i=0; i<$NUM_NODES; i++ )); do
  EL_NODE_IP="10.7.1.$((i+BOOT_NODES+2))"
  EL_NODE_NAME="pos_node$i-el"
  EL_NODE_PUBLIC_KEY=$(echo ${MINER_NODES[$i]} | jq -r .public_key)
  # stop docker
  docker stop $EL_NODE_NAME

  # Init node
  docker run --rm \
    -v $(pwd)/el/geth/.ethereum-$i:/.ethereum \
    -v $(pwd)/el/geth/genesis.json:/.genesis.json \
    ethereum/client-go:v1.11.5 \
    --datadir /.ethereum init /.genesis.json

  # Run geth node
  docker restart $EL_NODE_NAME

  sleep 5

done
