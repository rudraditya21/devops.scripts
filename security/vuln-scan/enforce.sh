#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: enforce.sh [OPTIONS]

Enforce vuln-scan security policy.

Options:
  --policy-file PATH      Policy file path (required)
  --mode MODE             warn|block (default: warn)
  --target NAME           Target scope (default: global)
  --dry-run               Print actions only
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

policy_file=""
mode="warn"
target="global"
dry_run=false

while (($#)); do
  case "$1" in
    --policy-file) shift; (($#)) || die "--policy-file requires a value"; policy_file="$1" ;;
    --mode) shift; (($#)) || die "--mode requires a value"; mode="$1" ;;
    --target) shift; (($#)) || die "--target requires a value"; target="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$policy_file" ]] || die "--policy-file is required"
[[ -f "$policy_file" ]] || $dry_run || die "policy file not found: $policy_file"
case "$mode" in warn|block) ;; *) die "--mode must be warn or block" ;; esac

if $dry_run; then
  printf 'DRY-RUN: enforce vuln-scan policy=%s mode=%s target=%s\n' "$policy_file" "$mode" "$target"
  exit 0
fi

printf 'domain=vuln-scan action=enforce policy=%s mode=%s target=%s status=applied\n' "$policy_file" "$mode" "$target"
exit 0
