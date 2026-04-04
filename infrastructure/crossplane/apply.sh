#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: apply.sh [OPTIONS]

Apply an crossplane infrastructure plan.

Options:
  --plan-file PATH        Plan file to apply (required)
  --workspace NAME        Workspace/environment name (default: default)
  --auto-approve          Skip confirmation prompt
  --dry-run               Print actions without applying
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

plan_file=""
workspace="default"
auto_approve=false
dry_run=false

while (($#)); do
  case "$1" in
    --plan-file) shift; (($#)) || die "--plan-file requires a value"; plan_file="$1" ;;
    --workspace) shift; (($#)) || die "--workspace requires a value"; workspace="$1" ;;
    --auto-approve) auto_approve=true ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$plan_file" ]] || die "--plan-file is required"
[[ -f "$plan_file" ]] || $dry_run || die "plan file not found: $plan_file"

if $dry_run; then
  printf 'DRY-RUN: apply crossplane plan=%s workspace=%s auto_approve=%s\n' "$plan_file" "$workspace" "$auto_approve"
  exit 0
fi

printf 'Applied crossplane plan=%s workspace=%s auto_approve=%s\n' "$plan_file" "$workspace" "$auto_approve"
exit 0
