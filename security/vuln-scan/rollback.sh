#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: rollback.sh [OPTIONS]

Rollback vuln-scan security changes.

Options:
  --change-id ID          Change identifier (required)
  --state-file PATH       State file path (default: .state/vuln-scan.state)
  --dry-run               Print actions only
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

change_id=""
state_file=".state/vuln-scan.state"
dry_run=false

while (($#)); do
  case "$1" in
    --change-id) shift; (($#)) || die "--change-id requires a value"; change_id="$1" ;;
    --state-file) shift; (($#)) || die "--state-file requires a value"; state_file="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$change_id" ]] || die "--change-id is required"

if $dry_run; then
  printf 'DRY-RUN: rollback vuln-scan change=%s\n' "$change_id"
  exit 0
fi

mkdir -p "$(dirname "$state_file")"
cat > "$state_file" <<STATE
domain=vuln-scan
change_id=$change_id
rolled_back_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STATE

printf 'Rollback state written to %s\n' "$state_file"
exit 0
