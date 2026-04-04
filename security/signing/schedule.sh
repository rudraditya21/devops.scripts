#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: schedule.sh [OPTIONS]

Schedule signing security runs.

Options:
  --cron SPEC             Cron schedule expression (required)
  --timezone TZ           Timezone name (default: UTC)
  --state-file PATH       Schedule state path (default: .state/signing-schedule.state)
  --dry-run               Print actions only
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

cron_spec=""
timezone="UTC"
state_file=".state/signing-schedule.state"
dry_run=false

while (($#)); do
  case "$1" in
    --cron) shift; (($#)) || die "--cron requires a value"; cron_spec="$1" ;;
    --timezone) shift; (($#)) || die "--timezone requires a value"; timezone="$1" ;;
    --state-file) shift; (($#)) || die "--state-file requires a value"; state_file="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$cron_spec" ]] || die "--cron is required"

if $dry_run; then
  printf 'DRY-RUN: schedule signing cron=%s timezone=%s\n' "$cron_spec" "$timezone"
  exit 0
fi

mkdir -p "$(dirname "$state_file")"
cat > "$state_file" <<STATE
domain=signing
cron=$cron_spec
timezone=$timezone
updated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STATE

printf 'Schedule state written to %s\n' "$state_file"
exit 0
