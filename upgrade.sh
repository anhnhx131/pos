#!/bin/bash
source $(pwd)/config.sh

MINER_NODES=(
    '{"public_key":"23081455D3FEaf17426176dfc5Ee7A3ce519aD33","private_key":"3c88fc7d33772dfa81e3c44347a3f9fc1df5946b70e3ba4f8a601e23e94d9072"}'
    '{"public_key":"d1d38fdc2669a694bf045b972a68654227143bd6","private_key":"f04e42bede52b46cf4c30b68eb56f96b87fcdae0d713861d72f9dfedaf0620aa"}'
    '{"public_key":"Cbba703129cC993b8c02Ce0AfB4Cd85E26ABa56c","private_key":"a4d13521428735961755d278f8d8f48e7cc35a14d07d29d8de8df9a7908bd590"}'
)

BEACON_VALIDATORS=(
    '{"crypto": {"kdf": {"function": "scrypt", "params": {"dklen": 32, "n": 262144, "r": 8, "p": 1, "salt": "f4dfc377099a54b44d9c50f8ddd739e077bb36f1c87b8168374629a9359d5d53"}, "message": ""}, "checksum": {"function": "sha256", "params": {}, "message": "65ebe315764bd3efe7bac5156012e9ff857a6c7cee09a426c5dc94ea9e1514f2"}, "cipher": {"function": "aes-128-ctr", "params": {"iv": "55efb1a066665d38a9e36eae63db976c"}, "message": "5addb8391f3bd52c3620726af765766572f34bc78dc6f7c4048bc0d33da04386"}}, "description": "", "pubkey": "a2513da6dee9e37f32862bc5b22d2a0422c81f61dffb49b75cf3a17195cb61384b8c40f05a4b46bf50b4d5daf9b85daf", "path": "m/12381/3600/0/0/0", "uuid": "996b0f24-fc0b-4d32-87e0-a45a909a304a", "version": 4}'
    '{"crypto": {"kdf": {"function": "scrypt", "params": {"dklen": 32, "n": 262144, "r": 8, "p": 1, "salt": "257e582e774ec26c787da9e9f2191e24deb11b709988e9664d7f91d7eac49fba"}, "message": ""}, "checksum": {"function": "sha256", "params": {}, "message": "c14295653a05bd61ec2771ecaa17fa878d367647101d5d45667b4164db4d5004"}, "cipher": {"function": "aes-128-ctr", "params": {"iv": "3c167479067e1e4b169d3fe67f0a9306"}, "message": "30b62704b9e3a6eee83382e3e4c4370e8a9563b1c78b7b16636b15d935a38ff0"}}, "description": "", "pubkey": "8803e45ba796f8a2eacfa16574a8abd4b0cddb32aeda9e764ff46c76f812a27d9575e439f9614a3b939e5901c884643f", "path": "m/12381/3600/1/0/0", "uuid": "85441a1a-f82d-4a9c-8815-8da57b182408", "version": 4}'
    '{"crypto": {"kdf": {"function": "scrypt", "params": {"dklen": 32, "n": 262144, "r": 8, "p": 1, "salt": "f6216e73b2233cc3d30b8ae3149eb8b2efcfba41514f29b4c2f39112e4abc730"}, "message": ""}, "checksum": {"function": "sha256", "params": {}, "message": "3459391936d0b764693b8b2298759dc862a13ef65169bd88f39e4b67a99cd6fb"}, "cipher": {"function": "aes-128-ctr", "params": {"iv": "9acef1407b7d054f2b91933b265def6c"}, "message": "d2c94cf242c774d61633b03d02fe2315b2ea48e4743768ab577d5d4fd80bdc1d"}}, "description": "", "pubkey": "b1558ab3653e735afddccb1f38f7e6367ed9feef55213f74081e7eaf3a6b01531bf9cc438d07d497e3a70c7d704d2ac8", "path": "m/12381/3600/2/0/0", "uuid": "9b232b19-6bf1-4e46-a250-2a691af0f59e", "version": 4}'
    '{"crypto": {"kdf": {"function": "scrypt", "params": {"dklen": 32, "n": 262144, "r": 8, "p": 1, "salt": "f735d2fbac8f455bda6289e299d2c2bca6248eb8bddcedf155adbf0632a652a9"}, "message": ""}, "checksum": {"function": "sha256", "params": {}, "message": "d0eebb50228c26ffb66d985d53129fa0f141c888713ae3b1accc496b0bd3729c"}, "cipher": {"function": "aes-128-ctr", "params": {"iv": "35f293bfad0c9760c9a0e7c739f65cb0"}, "message": "20be76645836e57c5e61286fc718da18f2a1329cc2b6c1a05d487c3d99f0dc7d"}}, "description": "", "pubkey": "b685469832ee59a4160062e752a39a6d3f9cdeb7c1522a416283babfc51bdfd9a6804bcf30aebd034c525885e1488e9b", "path": "m/12381/3600/3/0/0", "uuid": "d9709d9b-e6dc-4c3d-be16-07cb5b42ba6b", "version": 4}'
    '{"crypto": {"kdf": {"function": "scrypt", "params": {"dklen": 32, "n": 262144, "r": 8, "p": 1, "salt": "edc8420236d311fda52cab840b1448967ab9f414f35f39e59e0a35fb233d1163"}, "message": ""}, "checksum": {"function": "sha256", "params": {}, "message": "712fb61f9a2fccf2436b8a6a5db3b02f631b472838a86f439bb18fb604a6b454"}, "cipher": {"function": "aes-128-ctr", "params": {"iv": "242e686e805a55e24e0c57c2ec068b67"}, "message": "9df4028ebb1d58b1dd1f1e2e37a0aa1f936c5ae7e5e04686fe5660b5dc232a48"}}, "description": "", "pubkey": "aaf7fec6445f9d8c2d95baa46f89d91489ef4fedb49dbf68468adae0993b767a23b38a4cc2295913face91bc823d8fb0", "path": "m/12381/3600/4/0/0", "uuid": "cd9eea1d-9eb4-45f8-a1a8-97869c711899", "version": 4}'
)

NUM_NODES=3

# Run miner node
echo "Initializing Ethereum node..."

# Start additional nodes dynamically
for (( i=0; i<$NUM_NODES; i++ )); do
  EL_NODE_IP="10.7.1.$((i+2))"
  EL_NODE_NAME="pos_node$i-el"
  EL_NODE_PRIVATE_KEY=$(echo ${MINER_NODES[$i]} | jq -r .private_key)
  EL_NODE_PUBLIC_KEY=$(echo ${MINER_NODES[$i]} | jq -r .public_key)
  # beacon node
  BEACON_NODE_IP="10.7.2.$((i+2))"
  BEACON_NODE_NAME="pos_node$i-beacon"
  BEACON_NODE_PRIVATE_KEY=$(echo ${MINER_NODES[$i]} | jq -r .private_key)
  BEACON_NODE_PUBLIC_KEY=$(echo ${MINER_NODES[$i]} | jq -r .public_key)
  # validator
  VALIDATOR_NODE_IP="10.7.3.$((i+2))"
  VALIDATOR_NODE_NAME="pos_node$i-validator"

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
    gcr.io/prysmaticlabs/prysm/beacon-chain:v4.2.1 \
    --datadir=/data/beacondata \
    --min-sync-peers=1 \
    --bootstrap-node=enr:-MK4QByMttvazzFwFJbNcq0z2X3MR3Iv6v8eEUbxUuHSW5DLdhTKIWjXMikBPpDS5Cf9hKAj5M_gmt-Uxpj-XncmRDqGAZg8_SFhh2F0dG5ldHOIAAAAAAAAAACEZXRoMpBOXjq3AQAAhAEAAAAAAAAAgmlkgnY0gmlwhAoHAgKJc2VjcDI1NmsxoQJZJFLCdVOkj35zGdm8bpM_AN2a8g_a4GWoXwTHOBP_XYhzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A \
    --chain-config-file=/config/config.yaml \
    --chain-id=84 \
    --network-id=84 \
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
    $([ "$i" -eq 0 ] && echo "--p2p-priv-key=/bn/privkey" || echo "")

  # Run validator node
  if [ "$i" -ne 0 ]; then
    VALIDATOR_INDEX=$((i-1))
    # remove container
    docker rm -f $VALIDATOR_NODE_NAME
    # run validator client
    docker run -d \
      --name $VALIDATOR_NODE_NAME \
      --network $DOCKER_NETWORK_NAME \
      --ip $VALIDATOR_NODE_IP \
      -v $(pwd)/cl/validator-$i:/data \
      -v $(pwd)/cl/config:/config \
      gcr.io/prysmaticlabs/prysm/validator:v4.2.1 \
      --beacon-rpc-provider=$BEACON_NODE_IP:4000 \
      --datadir=/data/validatordata \
      --accept-terms-of-use \
      --chain-config-file=/config/config.yaml \
      --wallet-dir=/data/wallet \
      --wallet-password-file=/data/wallet/password.txt
  fi

  sleep 10

done
