#!/usr/bin/env bash
# shellcheck shell=bash

ensure_directory() {
  local path="$1"
  [[ -n "$path" ]] && mkdir -p "$path"
}

ensure_jwt_secret() {
  local secret_dir="./.eth/ee-secret"
  ensure_directory "$secret_dir"
  local secret_file="${secret_dir}/${JWT_SECRET_FILENAME:-jwtsecret}"
  if [[ -n "${JWT_SECRET:-}" ]]; then
    printf '%s\n' "${JWT_SECRET}" >"$secret_file"
  elif [[ ! -s "$secret_file" ]]; then  
    echo "Generating JWT secret"
    openssl rand -hex 32 | tr -d "\n" > "$secret_file"
  fi
  chmod 600 "$secret_file"
}

render_execution_genesis_from_env() {
  local target="$1"

  # Generate base JSON without conditional fields
  local temp_file="${target}.tmp"
  cat >"$temp_file"<<EOF
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
  "alloc": {
    "0000000000000000000000000000000000000000": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000001": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000002": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000003": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000004": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000005": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000006": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000007": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000008": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000009": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000000a": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000000b": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000000c": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000000d": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000000e": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000000f": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000010": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000011": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000012": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000013": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000014": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000015": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000016": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000017": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000018": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000019": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000001a": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000001b": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000001c": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000001d": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000001e": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000001f": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000020": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000021": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000022": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000023": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000024": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000025": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000026": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000027": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000028": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000029": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000002a": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000002b": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000002c": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000002d": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000002e": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000002f": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000030": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000031": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000032": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000033": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000034": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000035": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000036": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000037": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000038": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000039": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000003a": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000003b": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000003c": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000003d": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000003e": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000003f": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000040": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000041": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000042": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000043": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000044": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000045": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000046": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000047": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000048": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000049": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000004a": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000004b": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000004c": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000004d": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000004e": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000004f": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000050": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000051": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000052": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000053": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000054": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000055": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000056": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000057": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000058": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000059": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000005a": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000005b": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000005c": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000005d": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000005e": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000005f": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000060": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000061": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000062": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000063": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000064": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000065": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000066": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000067": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000068": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000069": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000006a": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000006b": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000006c": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000006d": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000006e": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000006f": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000070": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000071": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000072": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000073": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000074": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000075": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000076": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000077": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000078": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000079": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000007a": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000007b": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000007c": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000007d": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000007e": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000007f": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000080": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000081": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000082": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000083": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000084": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000085": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000086": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000087": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000088": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000089": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000008a": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000008b": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000008c": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000008d": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000008e": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000008f": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000090": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000091": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000092": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000093": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000094": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000095": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000096": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000097": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000098": {
        "balance": "0x1"
    },
    "0000000000000000000000000000000000000099": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000009a": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000009b": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000009c": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000009d": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000009e": {
        "balance": "0x1"
    },
    "000000000000000000000000000000000000009f": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000a0": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000a1": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000a2": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000a3": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000a4": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000a5": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000a6": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000a7": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000a8": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000a9": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000aa": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000ab": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000ac": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000ad": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000ae": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000af": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000b0": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000b1": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000b2": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000b3": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000b4": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000b5": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000b6": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000b7": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000b8": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000b9": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000ba": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000bb": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000bc": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000bd": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000be": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000bf": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000c0": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000c1": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000c2": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000c3": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000c4": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000c5": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000c6": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000c7": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000c8": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000c9": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000ca": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000cb": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000cc": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000cd": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000ce": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000cf": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000d0": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000d1": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000d2": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000d3": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000d4": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000d5": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000d6": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000d7": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000d8": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000d9": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000da": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000db": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000dc": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000dd": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000de": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000df": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000e0": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000e1": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000e2": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000e3": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000e4": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000e5": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000e6": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000e7": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000e8": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000e9": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000ea": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000eb": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000ec": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000ed": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000ee": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000ef": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000f0": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000f1": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000f2": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000f3": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000f4": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000f5": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000f6": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000f7": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000f8": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000f9": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000fa": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000fb": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000fc": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000fd": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000fe": {
        "balance": "0x1"
    },
    "00000000000000000000000000000000000000ff": {
        "balance": "0x1"
    },
    "0xa66Be233CF5a5193b54fFfbF8C20754dF73c70Df": {
        "balance": "0x0000000000000000000000000000000000000000033B2E3C9FD0803CE8000000"
    }
  },
  "number": "${EL_NUMBER:-0x0}",
  "gasUsed": "${EL_GAS_USED:-0x0}",
  "parentHash": "${EL_PARENT_HASH:-0x0000000000000000000000000000000000000000000000000000000000000000}"
}
EOF

  # Use jq to conditionally add fields if they are set
  if command -v jq >/dev/null 2>&1; then
    local jq_cmd="."
    
    # Add terminalTotalDifficulty if set
    if [[ -n "${EL_TERMINAL_TOTAL_DIFFICULTY:-}" ]]; then
      jq_cmd="${jq_cmd} | .config.terminalTotalDifficulty = ${EL_TERMINAL_TOTAL_DIFFICULTY}"
    fi
    
    # Add shanghaiTime if set
    if [[ -n "${EL_SHANGHAI_TIME:-}" ]]; then
      jq_cmd="${jq_cmd} | .config.shanghaiTime = ${EL_SHANGHAI_TIME}"
    fi

    # Add cancunTime if set
    if [[ -n "${EL_CANCUN_TIME:-}" ]]; then
      jq_cmd="${jq_cmd} | .config.cancunTime = ${EL_CANCUN_TIME}"
      # Add blobSchedule.cancun if all cancun blob configs are set
      jq_cmd="${jq_cmd} | .config.blobSchedule.cancun.target = ${EL_BLOB_CANCUN_TARGET}"
      jq_cmd="${jq_cmd} | .config.blobSchedule.cancun.max = ${EL_BLOB_CANCUN_MAX}"
      jq_cmd="${jq_cmd} | .config.blobSchedule.cancun.baseFeeUpdateFraction = ${EL_BLOB_CANCUN_BASE_FEE_UPDATE_FRACTION}"
    fi

    # Add pragueTime if set
    if [[ -n "${EL_PRAGUE_TIME:-}" ]]; then
      jq_cmd="${jq_cmd} | .config.pragueTime = ${EL_PRAGUE_TIME}"
      # Add blobSchedule.prague if all prague blob configs are set
        jq_cmd="${jq_cmd} | .config.blobSchedule.prague.target = ${EL_BLOB_PRAGUE_TARGET}"
        jq_cmd="${jq_cmd} | .config.blobSchedule.prague.max = ${EL_BLOB_PRAGUE_MAX}"
        jq_cmd="${jq_cmd} | .config.blobSchedule.prague.baseFeeUpdateFraction = ${EL_BLOB_PRAGUE_BASE_FEE_UPDATE_FRACTION}"
    fi
    
    # Apply jq transformations
    jq "${jq_cmd}" "$temp_file" >"$target"
    rm -f "$temp_file"
  else
    # Fallback: move temp file to target if jq is not available
    mv "$temp_file" "$target"
    echo "Warning: jq not found, conditional fields will not be added" >&2
  fi
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
  local genesis_dir="./.eth/geth"
  ensure_directory "$genesis_dir"
  local genesis_path="${genesis_dir}/${EL_GENESIS_FILE:-genesis.json}"
  if [[ -n "${EL_GENESIS_JSON:-}" ]]; then
    printf '%s\n' "${EL_GENESIS_JSON}" >"$genesis_path"
  elif [[ "${EL_FROM_ENV:-true}" != "false" ]]; then
    render_execution_genesis_from_env "$genesis_path"
  elif [[ ! -f "$genesis_path" ]]; then
    local template="${EL_GENESIS_TEMPLATE:-}"
    if [[ -n "$template" && -f "$template" ]]; then
      cp "$template" "$genesis_path"
    else
      echo "Missing execution genesis at ${genesis_path}. Provide EL_GENESIS_JSON or EL_GENESIS_TEMPLATE." >&2
      exit 1
    fi
  fi
}

prepare_consensus_files() {
  local config_file="./.eth/lighthouse/config/config.yaml"
  ensure_directory "$(dirname "$config_file")"
  if [[ -n "${CL_CONFIG_YAML:-}" ]]; then
    printf '%s\n' "${CL_CONFIG_YAML}" >"$config_file"
  elif [[ "${CL_FROM_ENV:-true}" != "false" ]]; then
    render_consensus_config_from_env "$config_file"
  elif [[ ! -f "$config_file" ]]; then
    local template="${CL_CONFIG_TEMPLATE:-}"
    if [[ -n "$template" && -f "$template" ]]; then
      cp "$template" "$config_file"
    else
      echo "Missing consensus config at ${config_file}. Provide CL_CONFIG_YAML or CL_CONFIG_TEMPLATE." >&2
      exit 1
    fi
  fi

  local deposit_contract_block_file="./.eth/lighthouse/config/deposit_contract_block.txt"
  ensure_directory "$(dirname "$deposit_contract_block_file")"
  if [[ -n "${CL_DEPOSIT_BLOCK:-}" ]]; then
    printf '%s\n' "${CL_DEPOSIT_BLOCK}" >"$deposit_contract_block_file"
  else
    echo "Missing deposit contract block file at ${CL_DEPOSIT_BLOCK}. Provide CL_DEPOSIT_BLOCK." >&2
    exit 1
  fi

  local genesis_ssz=".eth/lighthouse/config/genesis.ssz"
  if [[ -n "${CL_GENESIS_STATE_URL:-}" && ! -f "$genesis_ssz" ]]; then
    echo "Downloading genesis state from ${CL_GENESIS_STATE_URL}"
    curl -H "Accept: application/octet-stream" "${CL_GENESIS_STATE_URL}/eth/v2/debug/beacon/states/0" > "$genesis_ssz"
  fi
}

ensure_validator_materials() {
  local key_root="./.eth/lighthouse/validator_keys"
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

prepare_dora_files() {
    local config_file="./.explorer/dora/config.yaml"
    ensure_directory "$(dirname "$config_file")"

    cat >"$config_file"<<EOF
logging:
  #outputLevel: "info"
  #outputStderr: false

  #filePath: "explorer.log"
  #fileLevel: "warn"

# Chain network configuration
chain:
  #displayName: "Ephemery Iteration xy"

# HTTP Server configuration
server:
  host: "0.0.0.0" # Address to listen on
  port: "80" # Port to listen on

frontend:
  enabled: true # Enable or disable to web frontend
  debug: false
  minimize: false # minimize html templates

  # Name of the site, displayed in the title tag
  siteName: "Dora the Explorer"
  siteSubtitle: ""
  
  # link to EL Explorer
  ethExplorerLink: ""

  # file or inventory url to load validator names from
  validatorNamesYaml: ""
  validatorNamesInventory: ""

  # frontend features
  disablePageCache: false
  showSensitivePeerInfos: false
  showPeerDASInfos: false
  showSubmitDeposit: false
  showSubmitElRequests: false
  publicRpcUrl: $DORA_EL_RPC_URL
  
beaconapi:
  # beacon node rpc endpoints
  endpoints:
    - name: "local"
      url: $DORA_CL_RPC_URL

  # local cache for page models
  localCacheSize: 100 # 100MB

  # remote cache for page models
  redisCacheAddr: ""
  redisCachePrefix: ""

executionapi:
  # execution node rpc endpoints
  endpoints:
    - name: "local"
      url: $DORA_EL_RPC_URL
  
  logBatchSize: 1000
  depositDeployBlock: 0 # el block number from where to crawl the deposit contract (should be <=, but close to the deposit contract deployment block)
  electraDeployBlock: 0 # el block number from where to crawl the electra system contracts (should be <=, but close to electra fork activation block)

# indexer keeps track of the latest epochs in memory.
indexer:
  # max number of epochs to keep in memory
  inMemoryEpochs: 3

  # number of epochs to keep validator activity history for (high memory usage for large validator sets)
  activityHistoryLength: 6

  # disable synchronizing historic data
  disableSynchronizer: false

  # reset synchronization state to this epoch on startup - only use to resync database, comment out afterwards
  #resyncFromEpoch: 0

  # force re-synchronization of epochs that are already present in DB - only use to fix missing data after schema upgrades
  #resyncForceUpdate: true

  # number of seconds to pause the synchronization between each epoch (don't overload CL client)
  syncEpochCooldown: 2

  # maximum number of parallel beacon state requests (might cause high memory usage)
  maxParallelValidatorSetRequests: 1

# database configuration
database:
  engine: "sqlite" # sqlite / pgsql

  # sqlite settings (only used if engine is sqlite)
  sqlite:
    file: "./explorer-db.sqlite"

  # pgsql settings (only used if engine is pgsql)
  pgsql:
    host: "127.0.0.1"
    port: 5432
    user: ""
    password: ""
    name: ""
  pgsqlWriter: # optional separate writer connection (used for replication setups)
    host: ""
    port: 5432
    user: ""
    password: ""
    name: ""

# separate block db for storing block bodies (no archive beacon node required)
blockDb:
  engine: "none" # pebble / s3 / none (disable block db)

  # pebble settings (only used if engine is set to pebble)
  pebble:
    path: "./tmp-blockdb.peb"
    cacheSize: 100 # 100MB

  # s3 settings (only used if engine is set to s3)
  s3:
    bucket: ""
    endpoint: ""
    secure: false
    region: ""
    accessKey: ""
    secretKey: ""
    path: "" # path prefix

EOF
}

prepare_stack() {
  prepare_execution_files
  prepare_consensus_files
  ensure_jwt_secret
}
