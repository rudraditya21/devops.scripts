#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: delete-cluster.sh [OPTIONS]

Delete an AKS cluster.

Options:
  --name NAME               Cluster name (required)
  --resource-group NAME     Resource group (required)
  --subscription ID         Subscription override
  --yes                     Required for non-dry-run deletion
  --dry-run                 Print az command without executing
  -h, --help                Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

run_cmd() {
  if $dry_run; then
    printf 'DRY-RUN:' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 0
  fi
  "$@"
}

name=""
resource_group=""
subscription=""
yes=false
dry_run=false

while (($#)); do
  case "$1" in
    --name)
      shift
      (($#)) || die "--name requires a value"
      name="$1"
      ;;
    --resource-group)
      shift
      (($#)) || die "--resource-group requires a value"
      resource_group="$1"
      ;;
    --subscription)
      shift
      (($#)) || die "--subscription requires a value"
      subscription="$1"
      ;;
    --yes)
      yes=true
      ;;
    --dry-run)
      dry_run=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
  shift
done

command_exists az || die "az CLI is required but not found"
[[ -n "$name" ]] || die "--name is required"
[[ -n "$resource_group" ]] || die "--resource-group is required"
if ! $dry_run && ! $yes; then
  die "--yes is required for deletion"
fi

cmd=(az aks delete --name "$name" --resource-group "$resource_group" --yes)
[[ -n "$subscription" ]] && cmd+=(--subscription "$subscription")

run_cmd "${cmd[@]}"
