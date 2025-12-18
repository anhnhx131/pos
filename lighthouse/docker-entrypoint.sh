#!/bin/sh
set -e
echo "Running docker-entrypoint.sh for consensus service"

# Start with base arguments from entrypoint
set -- "$@"

# Conditional: boot-nodes (only if CL_BOOTNODE_ENR is set)
if [ -n "${CL_BOOTNODE_ENR}" ]; then
  set -- "$@" "--boot-nodes=${CL_BOOTNODE_ENR}"
fi

# Conditional: checkpoint-sync-url (only if CL_GENESIS_STATE_URL is set)
if [ -n "${CL_GENESIS_STATE_URL}" ]; then
  set -- "$@" "--checkpoint-sync-url=${CL_GENESIS_STATE_URL}"
fi

# Archive mode
if [ "${CL_ARCHIVE_MODE:-false}" = "true" ]; then
  set -- "$@" "--disable-backfill-rate-limiting --reconstruct-historic-states"
fi

# Add extra arguments from CL_EXTRAS if provided
if [ -n "${CL_EXTRAS}" ]; then
  # Split CL_EXTRAS by spaces and add each as a separate argument
  for arg in ${CL_EXTRAS}; do
    set -- "$@" "${arg}"
  done
fi

# Execute the command
exec "$@"
