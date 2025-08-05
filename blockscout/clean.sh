SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
docker rm -f $(docker ps -a | awk '{print $NF}' | grep -w "blockscout" | cat)
rm -Rf $SCRIPT_DIR/.ethereum*
