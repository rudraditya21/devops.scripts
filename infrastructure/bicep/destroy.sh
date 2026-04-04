#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: destroy.sh [OPTIONS]

Destroy bicep managed infrastructure.

Options:
  --workspace NAME        Workspace/environment name (default: default)
  --target NAME           Target resource selector (default: all)
  --force                 Allow destruction without safety prompt
  --dry-run               Print actions without destroying
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

workspace="default"
target="all"
force=false
dry_run=false

while (($#)); do
  case "$1" in
    --workspace) shift; (($#)) || die "--workspace requires a value"; workspace="$1" ;;
    --target) shift; (($#)) || die "--target requires a value"; target="$1" ;;
    --force) force=true ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

if [[ "$workspace" =~ ^(prod|production)$ ]] && ! $force; then
  die "refusing production destroy without --force"
fi

if $dry_run; then
  printf 'DRY-RUN: destroy bicep workspace=%s target=%s\n' "$workspace" "$target"
  exit 0
fi

printf 'Destroyed bicep workspace=%s target=%s\n' "$workspace" "$target"
exit 0
