#!/usr/bin/env sh
set -euo pipefail

DATABASE_URL="${DATABASE_URL:-}"
if [ -z "$DATABASE_URL" ]; then
  echo "DATABASE_URL is required for Blockscout." >&2
  exit 1
fi

if [ -z "${SECRET_KEY_BASE:-}" ]; then
  SECRET_KEY_BASE="$(openssl rand -hex 64)"
  export SECRET_KEY_BASE
fi

db_query=""
case "$DATABASE_URL" in
  *\?*)
    db_query="?${DATABASE_URL#*\?}"
    ;;
esac
db_host_part="${DATABASE_URL%%\?*}"
db_host_part="${db_host_part%/*}"
ready_url="${db_host_part}/postgres${db_query}"

echo "Running Blockscout migrations..."
bin/blockscout eval "Elixir.Explorer.ReleaseTasks.create_and_migrate()"

echo "Starting Blockscout..."
exec bin/blockscout start
