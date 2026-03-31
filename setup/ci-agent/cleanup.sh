#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: cleanup.sh [OPTIONS]

Clean CI agent workspace and artifacts.

Options:
  --workspace DIR          Workspace dir (default: ~/work/ci-agent)
  --artifacts-dir DIR      Artifacts dir (default: ~/work/ci-agent/artifacts)
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

wipe_children() {
  local d="$1"
  [[ -d "$d" ]] || return 0
  run_cmd find "$d" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

workspace="$HOME/work/ci-agent"
artifacts_dir="$HOME/work/ci-agent/artifacts"
dry_run=false

while (($#)); do
  case "$1" in
    --workspace) shift; (($#)) || die "--workspace requires a value"; workspace="$1" ;;
    --artifacts-dir) shift; (($#)) || die "--artifacts-dir requires a value"; artifacts_dir="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

wipe_children "$workspace"
wipe_children "$artifacts_dir"

exit 0
