SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

docker rm -f $(docker ps -a --format '{{.Names}}' | grep pos | cat)

# geth
rm -Rf $SCRIPT_DIR/el/geth/.ethereum*
# revert genesis.json
echo "Revert genesis.json..."
sed -i "s/\"shanghaiTime\": [0-9]*/\"shanghaiTime\": 9999999999999/g" el/geth/genesis.json
sed -i "s/\"pragueTime\": [0-9]*/\"pragueTime\": 9999999999999/g" el/geth/genesis.json
sed -i "s/\"cancunTime\": [0-9]*/\"cancunTime\": 9999999999999/g" el/geth/genesis.json

# beacon node
rm -Rf $SCRIPT_DIR/cl/node-*

# validator
rm -Rf $SCRIPT_DIR/cl/validator-*
