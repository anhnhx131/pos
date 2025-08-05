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
  docker run -d \
    --name $EL_NODE_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $EL_NODE_IP \
    $( [ "$i" -eq 0 ] && echo "-p 8545:8545" ) \
    -v $(pwd)/el/geth/.ethereum-$i:/.ethereum \
    ethereum/client-go:v1.11.5 \
    --nat=extip:$EL_NODE_IP \
    --http \
    --bootnodes=$BOOT_NODE \
    --http.api=eth,net,web3,debug,trace,engine,admin \
    --http.addr=0.0.0.0 \
    --http.corsdomain=* \
    --http.vhosts=* \
    --datadir=/.ethereum \
    --allow-insecure-unlock \
    $([ "$i" -eq 0 ] && echo "--unlock=$EL_NODE_PUBLIC_KEY" || echo "") \
    $([ "$i" -eq 0 ] && echo "--miner.etherbase=$EL_NODE_PUBLIC_KEY" || echo "") \
    $([ "$i" -eq 0 ] && echo "--mine" || echo "") \
    --networkid=84 \
    --authrpc.vhosts=* \
    --authrpc.addr=0.0.0.0 \
    --authrpc.jwtsecret=/.ethereum/jwtsecret \
    --syncmode=full \
    --password=/.ethereum/password.txt \
    $([ "$i" -eq 0 ] && echo "--nodekey /.ethereum/boot.key" || echo "")

  sleep 30

done
