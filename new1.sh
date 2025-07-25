source $(pwd)/config.sh

docker run -d \
  --name test-node \
  --network $DOCKER_NETWORK_NAME \
  --ip 10.7.2.10 \
  -v $(pwd)/cl/config:/config \
  -v $(pwd)/cl/bn:/bn \
  -v $(pwd)/cl/test-node:/data/beacondata \
  gcr.io/prysmaticlabs/prysm/beacon-chain:v4.2.1 \
  --help \
  --datadir=/data/beacondata \
  --min-sync-peers=1 \
  --bootstrap-node=enr:-MK4QByMttvazzFwFJbNcq0z2X3MR3Iv6v8eEUbxUuHSW5DLdhTKIWjXMikBPpDS5Cf9hKAj5M_gmt-Uxpj-XncmRDqGAZg8_SFhh2F0dG5ldHOIAAAAAAAAAACEZXRoMpBOXjq3AQAAhAEAAAAAAAAAgmlkgnY0gmlwhAoHAgKJc2VjcDI1NmsxoQJZJFLCdVOkj35zGdm8bpM_AN2a8g_a4GWoXwTHOBP_XYhzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A \
  --chain-config-file=/config/config.yaml \
  --chain-id=84 \
  --network-id=84 \
  --contract-deployment-block=0 \
  --deposit-contract=0x4242424242424242424242424242424242424242 \
  --http-web3provider=http://10.7.1.2:8551 \
  --accept-terms-of-use \
  --jwt-secret=/config/jwtsecret \
  --enable-debug-rpc-endpoints \
  --verbosity=debug \
  --rpc-host=0.0.0.0 \
  --rpc-port=4000 \
  --grpc-gateway-host=0.0.0.0 \
  --p2p-host-ip=10.7.2.10 \
  --p2p-local-ip=0.0.0.0 \
  --enable-upnp

# docker run -d \
#   -v $(pwd)/cl/config:/config \
#   gcr.io/prysmaticlabs/prysm/cmd/prysmctl:latest \
#   validator \
#   withdraw \
#   --help \
#   --beacon-rpc-provider=10.7.2.10:4000 \
#   --datadir=/data/validatordata \
#   --accept-terms-of-use \
#   --chain-config-file=/config/config.yaml \
#   --force-clear-db \
#   --wallet-dir=/data/wallet \
#   --wallet-password-file=/data/wallet/password.txt
