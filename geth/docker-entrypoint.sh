#!/bin/sh
set -e
echo "Running docker-entrypoint.sh"
# Create network directory
__datadir="--datadir /var/lib/geth"
__miner_command=""
__nodekey=""

if [ -n "${JWT_SECRET}" ]; then
  echo -n "${JWT_SECRET}" > /var/lib/geth/ee-secret/jwtsecret
  echo "JWT secret was supplied in .env"
fi

if [ -n "${EL_BOOT_NODE_KEY}" ]; then
  echo -n "${EL_BOOT_NODE_KEY}" > /var/lib/geth/nodekey
  __nodekey="--nodekey=/var/lib/geth/nodekey"
fi

if [ ! -f /var/lib/geth/ee-secret/jwtsecret ]; then
  echo "Generating JWT secret"
  __secret1=$(head -c 8 /dev/urandom | od -A n -t u8 | tr -d '[:space:]' | sha256sum | head -c 32)
  __secret2=$(head -c 8 /dev/urandom | od -A n -t u8 | tr -d '[:space:]' | sha256sum | head -c 32)
  echo -n "${__secret1}""${__secret2}" > /var/lib/geth/ee-secret/jwtsecret
fi

if [ -O "/var/lib/geth/ee-secret" ]; then
  # In case someone specifies JWT_SECRET but it's not a distributed setup
  chmod 777 /var/lib/geth/ee-secret
fi
if [ -O "/var/lib/geth/ee-secret/jwtsecret" ]; then
  chmod 666 /var/lib/geth/ee-secret/jwtsecret
fi

__ancient=""

if [ -n "${ANCIENT_DIR}" ] && [ ! "${ANCIENT_DIR}" = ".nada" ]; then
  echo "Using separate ancient directory at ${ANCIENT_DIR}."
  __ancient="--datadir.ancient /var/lib/ancient"
fi

# Init data only if chaindata doesn't exist
# if [ ! -d "/var/lib/geth/geth/chaindata" ]; then
# fi
echo "Initializing geth with genesis.json"
geth init ${__datadir} "/var/lib/geth/genesis.json"

# Clique miner
if [ "${CLIQUE_MINER}" = "true" ] && ! ls /var/lib/geth/keystore/UTC--* >/dev/null 2>&1; then
  echo "[Clique] Write password and private key to file"
  echo "${CLIQUE_MINER_PASSWORD}" > /var/lib/geth/password.txt
  echo "${CLIQUE_MINER_PRIVATE_KEY}" > /var/lib/geth/key.prv
  geth account import ${__datadir} --password /var/lib/geth/password.txt /var/lib/geth/key.prv
  __miner_command="--mine --miner.etherbase ${CLIQUE_MINER_ADDRESS} --unlock ${CLIQUE_MINER_ADDRESS} --password /var/lib/geth/password.txt --allow-insecure-unlock"
else 
  __bootnodes="--bootnodes=${EL_BOOTNODES}"
fi

# Set verbosity (case-insensitive matching)
_log_level=$(echo "${LOG_LEVEL}" | tr '[:upper:]' '[:lower:]')
case ${_log_level} in
  error)
    __verbosity="--verbosity 1"
    ;;
  warn)
    __verbosity="--verbosity 2"
    ;;
  info)
    __verbosity="--verbosity 3"
    ;;
  debug)
    __verbosity="--verbosity 4"
    ;;
  trace)
    __verbosity="--verbosity 5"
    ;;
  *)
    echo "LOG_LEVEL ${LOG_LEVEL} not recognized"
    __verbosity=""
    ;;
esac

if [ "${ARCHIVE_NODE}" = "true" ]; then
  echo "Geth archive node without pruning"
  if [ ! -d /var/lib/geth/geth/chaindata ] && [ ! -d /var/lib/goethereum/geth/chaindata ]; then
    touch /var/lib/geth/path-archive
  fi
  if [ -f /var/lib/geth/path-archive ]; then
    __prune="--syncmode=full --state.scheme=path --history.state=0"
  else
    __prune="--syncmode=full --gcmode=archive"
  fi
elif [ "${MINIMAL_NODE}" = "true" ]; then
  case "${NETWORK}" in
    mainnet | sepolia )
       echo "Geth minimal node with pre-merge history expiry"
      __prune="--history.chain postmerge"
      ;;
    * )
      echo "There is no pre-merge history for ${NETWORK} network, EL_MINIMAL_NODE has no effect."
      __prune=""
      ;;
  esac
else
  echo "Geth full node without history expiry"
  __prune=""
fi

exec "$@" ${__miner_command} ${__bootnodes} ${__nodekey} ${__ancient} ${__verbosity} ${EL_EXTRAS}

# # Word splitting is desired for the command line parameters
# # shellcheck disable=SC2086
# if [ -f /var/lib/geth/prune-marker ]; then
#   rm -f /var/lib/geth/prune-marker
#   if [ "${ARCHIVE_NODE}" = "true" ]; then
#     echo "Geth is an archive node. Not attempting to prune: Aborting."
#     exit 1
#   fi
# # Word splitting is desired for the command line parameters
# # shellcheck disable=SC2086
#   exec "$@" ${__miner_command} ${__ancient} ${EL_EXTRAS} prune-history
# else
  
# fi
