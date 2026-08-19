#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
service_root="$repo_root/services/igdb"

if [[ ! -f "$service_root/package.json" ]]; then
  echo "Metadata service is missing at: $service_root" >&2
  exit 1
fi

require_bun() {
  if ! command -v bun >/dev/null 2>&1; then
    echo "Bun is required for services/igdb. Install Bun 1.x and retry." >&2
    exit 1
  fi
}

run_in_service() {
  (
    cd "$service_root"
    "$@"
  )
}

install_dependencies() {
  require_bun
  run_in_service bun install --frozen-lockfile
}

verify_service() {
  install_dependencies
  run_in_service bun test
  run_in_service bun run build
}

require_runtime_credentials() {
  if [[ ! -f "$service_root/.env" &&
        ( -z "${TWITCH_CLIENT_ID:-}" || -z "${TWITCH_CLIENT_SECRET:-}" ) ]]; then
    echo "Metadata service credentials are missing." >&2
    echo "Create services/igdb/.env from services/igdb/.env.example or export TWITCH_CLIENT_ID and TWITCH_CLIENT_SECRET." >&2
    exit 1
  fi
}

usage() {
  cat <<'EOF'
Usage: tool/service.sh <command>

Commands:
  install   Install the locked Bun dependencies.
  verify    Install dependencies, run service tests, and compile the binary.
  test      Run service tests.
  build     Compile the production service binary.
  dev       Start the service with Bun hot reload.
  start     Start the service in the foreground.
  deploy    Build and start/reload the PM2 service from this monorepo.
  status    Show the PM2 service status.
  logs      Tail the PM2 service logs.
EOF
}

case "${1:-}" in
  install) install_dependencies ;;
  verify) verify_service ;;
  test)
    require_bun
    run_in_service bun test
    ;;
  build)
    require_bun
    run_in_service bun run build
    ;;
  dev)
    require_bun
    require_runtime_credentials
    run_in_service bun run dev
    ;;
  start)
    require_bun
    require_runtime_credentials
    run_in_service bun run start
    ;;
  deploy)
    require_bun
    require_runtime_credentials
    run_in_service bun run deploy
    ;;
  status)
    run_in_service pm2 describe igdb-service
    ;;
  logs)
    run_in_service pm2 logs igdb-service
    ;;
  help|-h|--help|"") usage ;;
  *)
    echo "Unknown service command: $1" >&2
    usage >&2
    exit 2
    ;;
esac
