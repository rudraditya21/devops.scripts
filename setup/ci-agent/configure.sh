#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: configure.sh [OPTIONS]

Configure CI agent runtime defaults.

Options:
  --config-file PATH       Config file path (default: ~/.config/devops-ci-agent/config.env)
  --queue NAME             Agent queue label (default: default)
  --workspace DIR          Agent workspace (default: ~/work/ci-agent)
  --artifacts-dir DIR      Agent artifacts dir (default: ~/work/ci-agent/artifacts)
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

config_file="$HOME/.config/devops-ci-agent/config.env"
queue="default"
workspace="$HOME/work/ci-agent"
artifacts_dir="$HOME/work/ci-agent/artifacts"
dry_run=false

while (($#)); do
  case "$1" in
    --config-file) shift; (($#)) || die "--config-file requires a value"; config_file="$1" ;;
    --queue) shift; (($#)) || die "--queue requires a value"; queue="$1" ;;
    --workspace) shift; (($#)) || die "--workspace requires a value"; workspace="$1" ;;
    --artifacts-dir) shift; (($#)) || die "--artifacts-dir requires a value"; artifacts_dir="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

run_cmd mkdir -p "$(dirname "$config_file")" "$workspace" "$artifacts_dir"

if $dry_run; then
  printf 'DRY-RUN: write %s\n' "$config_file" >&2
else
  cat > "$config_file" <<ENV
DEVOPS_CI_AGENT_QUEUE="$queue"
DEVOPS_CI_AGENT_WORKSPACE="$workspace"
DEVOPS_CI_AGENT_ARTIFACTS_DIR="$artifacts_dir"
ENV
fi

exit 0
