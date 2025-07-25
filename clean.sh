SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

docker rm -f $(docker ps -a --format '{{.Names}}' | grep pos | cat)

# geth
rm -Rf $SCRIPT_DIR/el/geth/.ethereum*

# beacon node
rm -Rf $SCRIPT_DIR/cl/node-*

# validator
rm -Rf $SCRIPT_DIR/cl/validator-*
