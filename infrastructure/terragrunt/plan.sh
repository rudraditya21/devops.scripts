#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: plan.sh [OPTIONS]

Create an terragrunt infrastructure plan.

Options:
  --workspace NAME        Workspace/environment name (default: default)
  --var-file PATH         Variable file path
  --output PATH           Output plan path
  --dry-run               Print actions without writing files
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

workspace="default"
var_file=""
output=""
dry_run=false

while (($#)); do
  case "$1" in
    --workspace) shift; (($#)) || die "--workspace requires a value"; workspace="$1" ;;
    --var-file) shift; (($#)) || die "--var-file requires a value"; var_file="$1" ;;
    --output) shift; (($#)) || die "--output requires a value"; output="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

if [[ -n "$var_file" ]]; then
  [[ -f "$var_file" ]] || $dry_run || die "var file not found: $var_file"
fi

plan=$(cat <<TXT
stack: terragrunt
action: plan
workspace: $workspace
var_file: ${var_file:-none}
TXT
)

if $dry_run; then
  printf 'DRY-RUN: create terragrunt plan for workspace=%s\n' "$workspace"
  exit 0
fi

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s\n' "$plan" > "$output"
else
  printf '%s\n' "$plan"
fi

exit 0
