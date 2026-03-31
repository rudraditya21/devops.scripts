#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: list-vms.sh [OPTIONS]

List Azure virtual machines with optional scope and output control.

Options:
  --resource-group NAME   Restrict to one resource group
  --subscription ID       Azure subscription override
  --output MODE           table|json|names (default: table)
  --show-details          Include power state and IP details
  --dry-run               Print az command without executing
  -h, --help              Show help
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

resource_group=""
subscription=""
output_mode="table"
show_details=false
dry_run=false

while (($#)); do
  case "$1" in
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
    --output)
      shift
      (($#)) || die "--output requires a value"
      case "$1" in
        table | json | names) output_mode="$1" ;;
        *) die "invalid --output value: $1" ;;
      esac
      ;;
    --show-details)
      show_details=true
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

cmd=(az vm list)
[[ -n "$resource_group" ]] && cmd+=(--resource-group "$resource_group")
[[ -n "$subscription" ]] && cmd+=(--subscription "$subscription")
$show_details && cmd+=(--show-details)

case "$output_mode" in
  table)
    cmd+=(--output table)
    ;;
  json)
    cmd+=(--output json)
    ;;
  names)
    cmd+=(--query '[].name' --output tsv)
    ;;
esac

run_cmd "${cmd[@]}"
