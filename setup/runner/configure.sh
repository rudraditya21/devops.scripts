#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: configure.sh [OPTIONS]

Configure runner defaults for devops.scripts execution.

Options:
  --env-file PATH          Env file to write (default: ~/.config/devops-runner/env)
  --workspace DIR          Default workspace path (default: ~/work)
  --artifacts-dir DIR      Default artifacts path (default: ~/work/artifacts)
  --log-level LEVEL        Runner log level (default: info)
  --dry-run                Print actions without executing
  -h, --help               Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

run_cmd() {
  if $dry_run; then
    printf 'DRY-RUN:' >&2; printf ' %q' "$@" >&2; printf '\n' >&2
    return 0
  fi
  "$@"
}

env_file="$HOME/.config/devops-runner/env"
workspace="$HOME/work"
artifacts_dir="$HOME/work/artifacts"
log_level="info"
dry_run=false

while (($#)); do
  case "$1" in
    --env-file) shift; (($#)) || die "--env-file requires a value"; env_file="$1" ;;
    --workspace) shift; (($#)) || die "--workspace requires a value"; workspace="$1" ;;
    --artifacts-dir) shift; (($#)) || die "--artifacts-dir requires a value"; artifacts_dir="$1" ;;
    --log-level) shift; (($#)) || die "--log-level requires a value"; log_level="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

config_dir="$(dirname "$env_file")"
run_cmd mkdir -p "$config_dir" "$workspace" "$artifacts_dir"

if $dry_run; then
  printf 'DRY-RUN: write %s\n' "$env_file" >&2
else
  cat > "$env_file" <<ENV
DEVOPS_RUNNER_WORKSPACE="$workspace"
DEVOPS_RUNNER_ARTIFACTS_DIR="$artifacts_dir"
DEVOPS_RUNNER_LOG_LEVEL="$log_level"
ENV
fi

exit 0
