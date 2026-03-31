#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: cleanup.sh [OPTIONS]

Clean runner workspace/artifacts and optional container caches.

Options:
  --workspace DIR          Workspace dir to clean (default: ~/work)
  --artifacts-dir DIR      Artifacts dir to clean (default: ~/work/artifacts)
  --docker-prune           Run `docker system prune -f` when docker is present
  --dry-run                Print actions without executing
  -h, --help               Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

command_exists() { command -v "$1" > /dev/null 2>&1; }

run_cmd() {
  if $dry_run; then
    printf 'DRY-RUN:' >&2; printf ' %q' "$@" >&2; printf '\n' >&2
    return 0
  fi
  "$@"
}

safe_wipe_children() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  run_cmd find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

workspace="$HOME/work"
artifacts_dir="$HOME/work/artifacts"
docker_prune=false
dry_run=false

while (($#)); do
  case "$1" in
    --workspace) shift; (($#)) || die "--workspace requires a value"; workspace="$1" ;;
    --artifacts-dir) shift; (($#)) || die "--artifacts-dir requires a value"; artifacts_dir="$1" ;;
    --docker-prune) docker_prune=true ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

safe_wipe_children "$workspace"
safe_wipe_children "$artifacts_dir"

if $docker_prune && command_exists docker; then
  run_cmd docker system prune -f
fi

exit 0
