#!/usr/bin/env bash
# shellcheck shell=bash

ensure_directory() {
  local path="$1"
  [[ -n "$path" ]] && mkdir -p "$path"
}

prepare_directories() {
  local paths=(
    "${GETH_DATA_DIR:-./data/el/geth}"
    "${EL_CONFIG_DIR:-./config/el}"
    "${LH_CONSENSUS_DATA_DIR:-./data/cl/consensus}"
    "${VALIDATOR_DATA_DIR:-./data/cl/validator}"
    "${BOOTNODE_DATA_DIR:-./data/cl/bootnode}"
    "${LH_CONFIG_DIR:-./config/lighthouse}"
    "${JWT_SECRET_DIR:-./shared/jwt}"
    "${DORA_DATA_DIR:-./dora/data}"
    "$(dirname "${CL_CONFIG_FILE:-${LH_CONFIG_DIR:-./config/lighthouse}/config.yaml}")"
    "$(dirname "${CL_DEPOSIT_BLOCK_FILE:-${LH_CONFIG_DIR:-./config/lighthouse}/deposit_contract_block.txt}")"
  )
  for dir in "${paths[@]}"; do
    ensure_directory "$dir"
  done
  local config_dir
  config_dir="$(dirname "${DORA_CONFIG_FILE:-./dora/config.yaml}")"
  ensure_directory "$config_dir"
}

ensure_jwt_secret() {
  local secret_dir="${JWT_SECRET_DIR:-./shared/jwt}"
  ensure_directory "$secret_dir"
  local secret_file="${secret_dir}/${JWT_SECRET_FILENAME:-jwtsecret}"
  if [[ -n "${JWT_SECRET:-}" ]]; then
    printf '%s\n' "${JWT_SECRET}" >"$secret_file"
  elif [[ ! -s "$secret_file" ]]; then
    od -An -tx1 -N32 /dev/urandom | tr -d ' \n' | head -c 64 >"$secret_file"
  fi
  chmod 600 "$secret_file"
}

render_execution_genesis_from_env() {
  local target="$1"
  local alloc_json
  if [[ -n "${EL_GENESIS_ALLOC_JSON:-}" ]]; then
    alloc_json="${EL_GENESIS_ALLOC_JSON}"
  elif [[ -n "${EL_GENESIS_ALLOC_FILE:-}" && -f "${EL_GENESIS_ALLOC_FILE}" ]]; then
    alloc_json="$(cat "${EL_GENESIS_ALLOC_FILE}")"
  else
    alloc_json="{}"
  fi

  cat >"$target"<<EOF
{
  "config": {
    "chainId": ${EL_CHAIN_ID:-84},
    "homesteadBlock": ${EL_HOMESTEAD_BLOCK:-0},
    "eip150Block": ${EL_EIP150_BLOCK:-0},
    "eip150Hash": "${EL_EIP150_HASH:-0x0}",
    "eip155Block": ${EL_EIP155_BLOCK:-0},
    "eip158Block": ${EL_EIP158_BLOCK:-0},
    "byzantiumBlock": ${EL_BYZANTIUM_BLOCK:-0},
    "constantinopleBlock": ${EL_CONSTANTINOPLE_BLOCK:-0},
    "petersburgBlock": ${EL_PETERSBURG_BLOCK:-0},
    "istanbulBlock": ${EL_ISTANBUL_BLOCK:-0},
    "MuirGlacierBlock": ${EL_MUIR_GLACIER_BLOCK:-0},
    "clique": {
      "period": ${EL_CLIQUE_PERIOD:-5},
      "epoch": ${EL_CLIQUE_EPOCH:-30000}
    },
    "londonBlock": ${EL_LONDON_BLOCK:-0},
    "muirGlacierBlock": ${EL_MUIR_GLACIER_BLOCK:-0},
    "berlinBlock": ${EL_BERLIN_BLOCK:-0}
  },
  "nonce": "${EL_NONCE:-0x0}",
  "timestamp": "${EL_TIMESTAMP:-0x5bfbe6b5}",
  "extraData": "${EL_EXTRA_DATA:-0x000000000000000000000000000000000000000000000000000000000000000057d68c4c9ee6dc6541ccfaf41a1125bbe17b5ce80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000}",
  "gasLimit": "${EL_GAS_LIMIT:-0x5f5e100}",
  "difficulty": "${EL_DIFFICULTY:-0x1}",
  "mixHash": "${EL_MIX_HASH:-0x0}",
  "coinbase": "${EL_COINBASE:-0x0000000000000000000000000000000000000000}",
  "alloc":
EOF
  printf '%s\n' "$alloc_json" >>"$target"
  cat >>"$target"<<EOF
,
  "number": "${EL_NUMBER:-0x0}",
  "gasUsed": "${EL_GAS_USED:-0x0}",
  "parentHash": "${EL_PARENT_HASH:-0x0000000000000000000000000000000000000000000000000000000000000000}"
}
EOF
}

render_consensus_config_from_env() {
  local target="$1"
  cat >"$target"<<EOF
PRESET_BASE: '${CL_PRESET_BASE:-gnosis}'
CONFIG_NAME: '${CL_CONFIG_NAME:-custom}'

# Genesis
MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: ${CL_MIN_GENESIS_ACTIVE_VALIDATOR_COUNT:-1}
MIN_GENESIS_TIME: ${CL_MIN_GENESIS_TIME:-0}
GENESIS_FORK_VERSION: ${CL_GENESIS_FORK_VERSION:-0x00000000}
GENESIS_DELAY: ${CL_GENESIS_DELAY:-0}
EPOCHS_PER_ETH1_VOTING_PERIOD: ${CL_EPOCHS_PER_ETH1_VOTING_PERIOD:-1}

# Forking
ALTAIR_FORK_VERSION: ${CL_ALTAIR_FORK_VERSION:-0x01000000}
ALTAIR_FORK_EPOCH: ${CL_ALTAIR_FORK_EPOCH:-1}
BELLATRIX_FORK_VERSION: ${CL_BELLATRIX_FORK_VERSION:-0x02000000}
BELLATRIX_FORK_EPOCH: ${CL_BELLATRIX_FORK_EPOCH:-1}
TERMINAL_TOTAL_DIFFICULTY: ${CL_TERMINAL_TOTAL_DIFFICULTY:-18446744073709551615}
TERMINAL_BLOCK_HASH: ${CL_TERMINAL_BLOCK_HASH:-0x0000000000000000000000000000000000000000000000000000000000000000}
TERMINAL_BLOCK_HASH_ACTIVATION_EPOCH: ${CL_TERMINAL_BLOCK_HASH_ACTIVATION_EPOCH:-18446744073709551615}
CAPELLA_FORK_VERSION: ${CL_CAPELLA_FORK_VERSION:-0x03000000}
CAPELLA_FORK_EPOCH: ${CL_CAPELLA_FORK_EPOCH:-18446744073709551615}
DENEB_FORK_VERSION: ${CL_DENEB_FORK_VERSION:-0x04000000}
DENEB_FORK_EPOCH: ${CL_DENEB_FORK_EPOCH:-18446744073709551615}
ELECTRA_FORK_VERSION: ${CL_ELECTRA_FORK_VERSION:-0x05000000}
ELECTRA_FORK_EPOCH: ${CL_ELECTRA_FORK_EPOCH:-18446744073709551615}

# Time parameters
SECONDS_PER_SLOT: ${CL_SECONDS_PER_SLOT:-12}
SLOTS_PER_EPOCH: ${CL_SLOTS_PER_EPOCH:-32}
SECONDS_PER_ETH1_BLOCK: ${CL_SECONDS_PER_ETH1_BLOCK:-14}
MIN_VALIDATOR_WITHDRAWABILITY_DELAY: ${CL_MIN_VALIDATOR_WITHDRAWABILITY_DELAY:-256}
SHARD_COMMITTEE_PERIOD: ${CL_SHARD_COMMITTEE_PERIOD:-256}
ETH1_FOLLOW_DISTANCE: ${CL_ETH1_FOLLOW_DISTANCE:-2048}

# Validator cycle
INACTIVITY_SCORE_BIAS: ${CL_INACTIVITY_SCORE_BIAS:-4}
INACTIVITY_SCORE_RECOVERY_RATE: ${CL_INACTIVITY_SCORE_RECOVERY_RATE:-16}
EJECTION_BALANCE: ${CL_EJECTION_BALANCE:-16000000000}
MIN_PER_EPOCH_CHURN_LIMIT: ${CL_MIN_PER_EPOCH_CHURN_LIMIT:-4}
CHURN_LIMIT_QUOTIENT: ${CL_CHURN_LIMIT_QUOTIENT:-65536}
PROPOSER_SCORE_BOOST: ${CL_PROPOSER_SCORE_BOOST:-40}

# Deposit contract
DEPOSIT_CHAIN_ID: ${CL_DEPOSIT_CHAIN_ID:-1}
DEPOSIT_NETWORK_ID: ${CL_DEPOSIT_NETWORK_ID:-1}
DEPOSIT_CONTRACT_ADDRESS: ${CL_DEPOSIT_CONTRACT_ADDRESS:-0x0000000000000000000000000000000000000000}
EOF
}

prepare_execution_files() {
  local genesis_dir="${EL_CONFIG_DIR:-./config/el}"
  ensure_directory "$genesis_dir"
  local genesis_path="${genesis_dir}/${EL_GENESIS_FILE:-genesis.json}"
  if [[ -n "${EL_GENESIS_JSON:-}" ]]; then
    printf '%s\n' "${EL_GENESIS_JSON}" >"$genesis_path"
  elif [[ ! -f "$genesis_path" ]]; then
    if [[ -n "${EL_FROM_ENV:-true}" ]]; then
      render_execution_genesis_from_env "$genesis_path"
    else
      local template="${EL_GENESIS_TEMPLATE:-}"
      if [[ -n "$template" && -f "$template" ]]; then
        cp "$template" "$genesis_path"
      else
        echo "Missing execution genesis at ${genesis_path}. Provide EL_GENESIS_JSON or EL_GENESIS_TEMPLATE." >&2
        exit 1
      fi
    fi
  fi
}

prepare_consensus_files() {
  local config_file="${CL_CONFIG_FILE:-${LH_CONFIG_DIR:-./config/lighthouse}/config.yaml}"
  ensure_directory "$(dirname "$config_file")"
  if [[ -n "${CL_CONFIG_YAML:-}" ]]; then
    printf '%s\n' "${CL_CONFIG_YAML}" >"$config_file"
  elif [[ ! -f "$config_file" ]]; then
    if [[ -n "${CL_FROM_ENV:-true}" ]]; then
      render_consensus_config_from_env "$config_file"
    else
      local template="${CL_CONFIG_TEMPLATE:-}"
      if [[ -n "$template" && -f "$template" ]]; then
        cp "$template" "$config_file"
      else
        echo "Missing consensus config at ${config_file}. Provide CL_CONFIG_YAML or CL_CONFIG_TEMPLATE." >&2
        exit 1
      fi
    fi
  fi

  local deposit_file="${CL_DEPOSIT_BLOCK_FILE:-${LH_CONFIG_DIR:-./config/lighthouse}/deposit_contract_block.txt}"
  ensure_directory "$(dirname "$deposit_file")"
  if [[ -n "${CL_DEPOSIT_BLOCK:-}" ]]; then
    printf '%s\n' "${CL_DEPOSIT_BLOCK}" >"$deposit_file"
  elif [[ ! -f "$deposit_file" ]]; then
    local deposit_template="${CL_DEPOSIT_BLOCK_TEMPLATE:-}"
    if [[ -n "$deposit_template" && -f "$deposit_template" ]]; then
      cp "$deposit_template" "$deposit_file"
    else
      echo "Missing deposit contract block file at ${deposit_file}. Provide CL_DEPOSIT_BLOCK or CL_DEPOSIT_BLOCK_TEMPLATE." >&2
      exit 1
    fi
  fi
}

ensure_validator_materials() {
  local key_root="${VALIDATOR_IMPORT_DIR:-${VALIDATOR_DATA_DIR:-./data/cl/validator}/validator_keys}"
  mkdir -p "$key_root"
  local key_dir
  key_dir="$(cd "$key_root" && pwd)"

  local key_file="${key_dir}/${VALIDATOR_KEYSTORE_FILENAME:-keystore.json}"
  local password_file="${key_dir}/${VALIDATOR_PASSWORD_FILENAME:-password.txt}"

  local original_umask
  original_umask=$(umask)
  umask 077

  if [[ -n "${VALIDATOR_KEY_JSON:-}" ]]; then
    printf '%s\n' "${VALIDATOR_KEY_JSON}" >"$key_file"
  elif [[ ! -s "$key_file" ]]; then
    echo "Validator keystore missing. Set VALIDATOR_KEY_JSON or place a file at $key_file" >&2
    umask "$original_umask"
    exit 1
  fi

  if [[ -n "${VALIDATOR_KEY_PASSWORD:-}" ]]; then
    printf '%s\n' "${VALIDATOR_KEY_PASSWORD}" >"$password_file"
  elif [[ ! -s "$password_file" ]]; then
    echo "Validator password missing. Set VALIDATOR_KEY_PASSWORD or place a file at $password_file" >&2
    umask "$original_umask"
    exit 1
  fi

  umask "$original_umask"
}

prepare_stack() {
  prepare_directories
  prepare_execution_files
  prepare_consensus_files
  ensure_jwt_secret
}

