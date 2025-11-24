#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREPARE_SCRIPT="${PROJECT_ROOT}/scripts/prepare.sh"
if [[ ! -f "$PREPARE_SCRIPT" ]]; then
  echo "Missing prepare helper at $PREPARE_SCRIPT" >&2
  exit 1
fi
# shellcheck source=scripts/prepare.sh
source "$PREPARE_SCRIPT"

usage() {
  cat <<'EOF'
Usage: ./start.sh <command> [env-file]

Commands:
  bootnode     Start only the bootnode service
  clique       Start only the clique service
  beacon           Start execution + beacon node (no validator client)
  beacon-vc        Start execution + beacon node + validator client
  import-keys  Materialize validator key/password files & run import job
  dora         Start dora explorer
  build        Build images defined in the compose files
  down         Stop and remove the running stack

An optional env-file argument overrides the default.env file.
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

resolve_path() {
  local input="$1"
  if [[ "$input" = /* ]]; then
    printf '%s\n' "$input"
    return
  fi
  printf '%s/%s\n' "$(pwd)" "$input"
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  local command="$1"
  local env_file="${2:-${ENV_FILE:-${PROJECT_ROOT}/default.env}}"
  local env_path
  env_path="$(resolve_path "$env_file")"

  if [[ ! -f "$env_path" ]]; then
    echo "Env file not found: $env_path" >&2
    exit 1
  fi

  require_cmd docker
  if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose plugin (docker compose) is required." >&2
    exit 1
  fi

  cd "$PROJECT_ROOT"
  set -a
  # shellcheck disable=SC1090
  source "$env_path"
  set +a

  local compose_files_str="${COMPOSE_FILE:-geth.yml:lighthouse-bn-only.yml:lighthouse.yml:dora.yml}"
  IFS=':' read -r -a compose_files <<<"$compose_files_str"
  local compose_args=()
  for file in "${compose_files[@]}"; do
    compose_args+=(-f "$file")
  done

  compose() {
    docker compose --env-file "$env_path" "${compose_args[@]}" "$@"
  }

  case "$command" in
    bootnode)
      # Run only the Lighthouse bootnode service
      prepare_stack
      compose up -d bootnode
      ;;
    beacon)
      # Beacon node without validator client: execution + consensus
      prepare_stack
      compose up -d execution consensus
      ;;
    clique)
      # Clique node: execution
      prepare_stack
      compose up -d execution
      ;;
    beacon-vc)
      # Beacon node with validator client: execution + consensus + validator
      prepare_stack
      ensure_validator_materials
      compose up -d execution consensus validator
      ;;
    dora)
      # Dora explorer (with its required execution + consensus dependencies)
      prepare_stack
      prepare_dora_files
      compose up -d dora
      ;;
    import-keys)
      prepare_stack
      ensure_validator_materials
      compose run --rm validator-import
      ;;
    build)
      compose build
      ;;
    down)
      compose down
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
