#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: replication-check.sh [OPTIONS]

Check mariadb replication lag thresholds.

Options:
  --lag-ms N              Observed replication lag in ms (required)
  --max-lag-ms N          Maximum allowed lag (default: 5000)
  --replica-count N       Number of replicas (default: 1)
  --json                  Emit JSON output
  --strict                Exit non-zero if status is not healthy
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

lag_ms=""
max_lag_ms="5000"
replica_count="1"
json=false
strict=false

while (($#)); do
  case "$1" in
    --lag-ms) shift; (($#)) || die "--lag-ms requires a value"; lag_ms="$1" ;;
    --max-lag-ms) shift; (($#)) || die "--max-lag-ms requires a value"; max_lag_ms="$1" ;;
    --replica-count) shift; (($#)) || die "--replica-count requires a value"; replica_count="$1" ;;
    --json) json=true ;;
    --strict) strict=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$lag_ms" ]] || die "--lag-ms is required"
[[ "$lag_ms" =~ ^[0-9]+$ ]] || die "--lag-ms must be numeric"
[[ "$max_lag_ms" =~ ^[0-9]+$ ]] || die "--max-lag-ms must be numeric"
[[ "$replica_count" =~ ^[0-9]+$ ]] || die "--replica-count must be numeric"

status="healthy"
if (( replica_count == 0 )); then
  status="critical"
elif (( lag_ms > max_lag_ms )); then
  status="warn"
fi

if $json; then
  printf '{"engine":"mariadb","lag_ms":%s,"max_lag_ms":%s,"replica_count":%s,"status":"%s"}\n' \
    "$lag_ms" "$max_lag_ms" "$replica_count" "$status"
else
  printf 'engine: mariadb\n'
  printf 'lag_ms: %s\n' "$lag_ms"
  printf 'max_lag_ms: %s\n' "$max_lag_ms"
  printf 'replica_count: %s\n' "$replica_count"
  printf 'status: %s\n' "$status"
fi

if $strict && [[ "$status" != "healthy" ]]; then
  exit 1
fi

exit 0
