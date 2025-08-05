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
    '{"crypto": {"kdf": {"function": "scrypt", "params": {"dklen": 32, "n": 262144, "r": 8, "p": 1, "salt": "19e477e48d3d5bd8759073982c56f98efcc449c9566f3291f99c9e75082cebb0"}, "message": ""}, "checksum": {"function": "sha256", "params": {}, "message": "ec2bb8a0e5755c5c9789eb7c550ac33a6ad386bb24e6998a7e79d2154e974241"}, "cipher": {"function": "aes-128-ctr", "params": {"iv": "06243620d28ca67925ee3b543bdff4d8"}, "message": "510878b5204be4a4cdd1388cd469f534eeac069cc250ec04548ae0396466b6d2"}}, "description": "", "pubkey": "a46aef6dda88f07672390bd642d0de2d1291dabc8889bcbec46c7d685e4cadbd7ac250dcd3313d382f2559e7322e130b", "path": "m/12381/3600/0/0/0", "uuid": "1bbeb74d-a5b7-4db6-97c4-a38bb2bd89b2", "version": 4}'
)

VALDAITOR_KEY_PASSWORD="password"
WALLET_PASSWORD="DguT9Mae0JkzP4ycirCH@@@@" 

SUBNET=10.7.0.0/16

# Create docker network if not exists
if ! docker network inspect $DOCKER_NETWORK_NAME >/dev/null 2>&1; then
  docker network create $DOCKER_NETWORK_NAME --driver bridge --subnet $SUBNET
fi

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

  # define geth data dir
  mkdir -p $(pwd)/el/geth/.ethereum-$i
  echo $JWT_SECRET > $(pwd)/el/geth/.ethereum-$i/jwtsecret

  if [ "$i" -eq 0 ]; then
    # Create keystore
  echo $EL_NODE_PRIVATE_KEY > $(pwd)/el/geth/.ethereum-$i/private.key
  echo "password" > $(pwd)/el/geth/.ethereum-$i/password.txt
  
  if [ $i == 0 ]; then
    echo $BOOT_NODE_KEY > $(pwd)/el/geth/.ethereum-$i/boot.key
  fi

  docker run --rm \
    -v $(pwd)/el/geth/.ethereum-$i:/.ethereum \
    ethereum/client-go:v1.11.6 \
    account import --datadir /.ethereum --password /.ethereum/password.txt /.ethereum/private.key
  fi

  # Init node
  docker run --rm \
    -v $(pwd)/el/geth/.ethereum-$i:/.ethereum \
    -v $(pwd)/el/geth/genesis.json:/.genesis.json \
    ethereum/client-go:v1.11.6 \
    --datadir /.ethereum init /.genesis.json

  # Run geth node
  docker run -d \
    --name $EL_NODE_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $EL_NODE_IP \
    $( [ "$i" -eq 0 ] && echo "-p 8545:8545" ) \
    -v $(pwd)/el/geth/.ethereum-$i:/.ethereum \
    ethereum/client-go:v1.11.6 \
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

  if [ "$i" -gt 1 ]; then
    docker run -d\
      --name $BEACON_NODE_NAME \
      --network $DOCKER_NETWORK_NAME \
      --ip $BEACON_NODE_IP \
      -p 350$i:3500 \
      -v $(pwd)/cl/config:/config \
      -p 35$i:3500 \
      sigp/lighthouse:v4.6.0 \
      lighthouse \
      beacon_node \
      --datadir=/data \
      --http \
      --http-address=0.0.0.0 \
      --http-port=3500 \
      --http-allow-origin=* \
      --debug-level=debug \
      --execution-endpoint=http://$EL_NODE_IP:8551 \
      --execution-jwt=/config/jwtsecret \
      --testnet-dir=/config \
      --boot-nodes=enr:-IS4QPOOGJE5V8GmhjshFUZ0pHWWWV008jgMGH3reH3HMtoEIR8UPrnl4OQO4xNSuwAtcgL6Omf4YPqi0zxMYO1GevUBgmlkgnY0gmlwhAoHAgKJc2VjcDI1NmsxoQOIhz10UYFO65iCNMMmcXHJQmk2FRNrqm0KoNtpBCicpoN1ZHCCIyg,enr:-IS4QATvRDQtMnslfe2DDfQ9au3gvF0oD9yrUswhLMWycafWPLOU9ZjXG0L0m9RJq-7V3lFhKXm9nVslPfizMgvfQZsBgmlkgnY0gmlwhAoHAgOJc2VjcDI1NmsxoQLh78RCFhcrgZ5tKgayyL9TTVXnK8mIlzBZoWiYQqdlUoN1ZHCCIyg \
      --disable-upnp \
      --enr-address=$BEACON_NODE_IP \
      --listen-address=$BEACON_NODE_IP \
      --enr-tcp-port=9000 \
      --enr-udp-port=9000 \
      --enable-private-discovery \
  else
    docker run -d \
      --name $BEACON_NODE_NAME \
      --network $DOCKER_NETWORK_NAME \
      --ip $BEACON_NODE_IP \
      -p 350$i:3500 \
      -v $(pwd)/cl/bn$i:/data \
      -v $(pwd)/cl/config:/config \
      sigp/lighthouse:v4.6.0 \
      lighthouse \
      boot_node \
      --datadir=/data \
      --testnet-dir=/config \
      --disable-packet-filter \
      --enable-enr-auto-update \
      --enr-address=$BEACON_NODE_IP \
      --listen-address=$BEACON_NODE_IP
  fi

  # Run validator node
  if [ "$i" -gt 1 ]; then
    VALIDATOR_INDEX=$((i-2))
    # create key
    mkdir -p $(pwd)/cl/validator-$i
    mkdir -p $(pwd)/cl/validator-$i/wallet
    mkdir -p $(pwd)/cl/validator-$i/validator_keys
    echo ${BEACON_VALIDATORS[$VALIDATOR_INDEX]} > $(pwd)/cl/validator-$i/validator_keys/keystore.json
    echo $VALDAITOR_KEY_PASSWORD > $(pwd)/cl/validator-$i/validator_keys/password.txt
    echo $WALLET_PASSWORD > $(pwd)/cl/validator-$i/wallet/password.txt

    # import keystore
    docker run --rm \
      -v $(pwd)/cl/validator-$i:/data \
      -v $(pwd)/cl/config:/config \
      sigp/lighthouse:v4.6.0 \
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
      sigp/lighthouse:v4.6.0 \
      lighthouse \
      validator_client \
      --validators-dir=/data/validators \
      --testnet-dir=/config \
      --beacon-nodes=http://$BEACON_NODE_IP:3500
  fi

done

# Run dora explorer
sh dora/start.sh

# deposit
sleep 3
sh deposit.sh
