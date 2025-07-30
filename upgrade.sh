#!/bin/bash
source $(pwd)/config.sh

# Run miner node
echo "Initializing Ethereum node..."

# Start additional nodes dynamically
for (( i=0; i<$NUM_NODES; i++ )); do
  EL_NODE_IP="10.7.1.$((i+2))"
  # beacon node
  BEACON_NODE_IP="10.7.2.$((i+2))"
  BEACON_NODE_NAME="pos_node$i-beacon"
  # validator
  VALIDATOR_NODE_IP="10.7.3.$((i+2))"
  VALIDATOR_NODE_NAME="pos_node$i-validator"
  VALIDATOR_INDEX=$((i-2))

  # Run validator node
  if [ "$i" -ne 0 ]; then
    # remove container
    docker stop $VALIDATOR_NODE_NAME
    # remove container
    docker rm -f $VALIDATOR_NODE_NAME
  fi

  # Stop beacon node
  docker rm -f $BEACON_NODE_NAME

  # Run beacon node
  docker run -d \
    --name $BEACON_NODE_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $BEACON_NODE_IP \
    $( [ "$i" -eq 0 ] && echo "-p 3500:3500" ) \
    -v $(pwd)/cl/config:/config \
    -v $(pwd)/cl/bn:/bn \
    -v $(pwd)/cl/node-$i:/data/beacondata \
    gcr.io/prysmaticlabs/prysm/beacon-chain:v3.2.0 \
    --datadir=/data/beacondata \
    --min-sync-peers=0 \
    --bootstrap-node=enr:-MK4QNEUb1iPB3uijEwaIcGV5DgEeMDGSkUiSbuf92cWUO3vZLSVoamK0byi7FjhvBIUYYIWTjhPIsbsAA_37H1k-VaGAZhanexNh2F0dG5ldHOIAAAAAAAAAACEZXRoMpC2eNdHAQAAhAEAAAAAAAAAgmlkgnY0gmlwhAoHAgKJc2VjcDI1NmsxoQJZJFLCdVOkj35zGdm8bpM_AN2a8g_a4GWoXwTHOBP_XYhzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A,enr:-MK4QE1ufdj0_mtQqFV54k4UsrRZ9HNGRImX05aQqTQp2mGiUZOlolyxcDhWB1cfjT_imXgfB15_4OWZuCQrMUfxKfqGAZhane3Kh2F0dG5ldHOIAAAAAAAAAACEZXRoMpC2eNdHAQAAhAEAAAAAAAAAgmlkgnY0gmlwhAoHAgOJc2VjcDI1NmsxoQLloM8VukrmSVDetKjK1tdPhqWcNs3A-uX7Lyu-yNSyD4hzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A \
    --chain-config-file=/config/config.yaml \
    --chain-id=84 \
    --network-id=84 \
    --force-clear-db \
    --contract-deployment-block=0 \
    --deposit-contract=0x4242424242424242424242424242424242424242 \
    --execution-endpoint=http://$EL_NODE_IP:8551 \
    --accept-terms-of-use \
    --jwt-secret=/config/jwtsecret \
    --enable-debug-rpc-endpoints \
    --verbosity=debug \
    --rpc-host=0.0.0.0 \
    --rpc-port=4000 \
    --grpc-gateway-host=0.0.0.0 \
    --p2p-host-ip=$BEACON_NODE_IP \
    --p2p-local-ip=0.0.0.0 \
    --enable-upnp \
    $([ "$i" -eq 0 ] || [ "$i" -eq 1 ] && echo "--p2p-priv-key=/bn/privkey$i" || echo "")

    if [ "$i" -gt 1 ]; then
      # run validator client
      docker run -d \
        --name $VALIDATOR_NODE_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $VALIDATOR_NODE_IP \
        -v $(pwd)/cl/validator-$i:/data \
        -v $(pwd)/cl/config:/config \
        gcr.io/prysmaticlabs/prysm/validator:v3.2.0 \
        --beacon-rpc-provider=$BEACON_NODE_IP:4000 \
        --datadir=/data/validatordata \
        --accept-terms-of-use \
        --force-clear-db \
        --chain-config-file=/config/config.yaml \
        --wallet-dir=/data/wallet \
        --wallet-password-file=/data/wallet/password.txt
    fi

  sleep 30

done
