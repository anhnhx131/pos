#!/bin/sh
set -e
echo "Running docker-entrypoint-vc.sh for validator service"

# Start with base arguments from entrypoint
set -- "$@"

# Conditional: graffiti (only if GRAFFITI is set and DEFAULT_GRAFFITI is not true)
if [ -n "${GRAFFITI}" ] && [ "${DEFAULT_GRAFFITI:-false}" != "true" ]; then
  set -- "$@" "--graffiti=${GRAFFITI}"
fi

# Conditional: doppelganger (only if DOPPELGANGER is set and not empty)
if [ -n "${DOPPELGANGER}" ]; then
  if [ "${DOPPELGANGER}" = "true" ] || [ "${DOPPELGANGER}" = "1" ]; then
    set -- "$@" "--enable-doppelganger-protection"
  fi
fi

# Conditional: MEV boost (only if MEV_BOOST is enabled)
if [ -n "${MEV_BOOST}" ] && [ "${MEV_BOOST}" != "false" ] && [ "${MEV_BOOST}" != "0" ]; then
  if [ -n "${MEV_NODE}" ]; then
    set -- "$@" "--builder-proposals"
    set -- "$@" "--suggested-fee-recipient=${MEV_NODE}"
  fi
  if [ -n "${MEV_BUILD_FACTOR}" ]; then
    set -- "$@" "--builder-profit-threshold=${MEV_BUILD_FACTOR}"
  fi
fi

# Conditional: distributed attestation aggregation
if [ "${ENABLE_DIST_ATTESTATION_AGGR:-false}" = "true" ]; then
  set -- "$@" "--enable-distributed-attestation-aggregation"
fi

# Add extra arguments from VC_EXTRAS if provided
if [ -n "${VC_EXTRAS}" ]; then
  # Split VC_EXTRAS by spaces and add each as a separate argument
  for arg in ${VC_EXTRAS}; do
    set -- "$@" "${arg}"
  done
fi

# Execute the command
exec "$@"

