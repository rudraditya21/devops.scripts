#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: healthcheck.sh [OPTIONS]

Run a elasticsearch endpoint healthcheck.

Options:
  --host HOST              Hostname or IP (default: 127.0.0.1)
  --port N                 TCP port (default: 9200)
  --timeout N              Timeout seconds (default: 3)
  --json                   Emit JSON output
  --strict                 Exit non-zero when unhealthy
  -h, --help               Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

host="127.0.0.1"
port="9200"
timeout_sec="3"
json=false
strict=false

while (($#)); do
  case "$1" in
    --host) shift; (($#)) || die "--host requires a value"; host="$1" ;;
    --port) shift; (($#)) || die "--port requires a value"; port="$1" ;;
    --timeout) shift; (($#)) || die "--timeout requires a value"; timeout_sec="$1" ;;
    --json) json=true ;;
    --strict) strict=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ "$port" =~ ^[0-9]+$ ]] || die "--port must be numeric"
[[ "$timeout_sec" =~ ^[0-9]+$ ]] || die "--timeout must be numeric"

status="unhealthy"
message="tcp check failed"
if command -v nc >/dev/null 2>&1; then
  if nc -z -w "$timeout_sec" "$host" "$port" >/dev/null 2>&1; then
    status="healthy"
    message="tcp connect ok"
  fi
elif command -v timeout >/dev/null 2>&1; then
  if timeout "$timeout_sec" bash -c "</dev/tcp/$host/$port" >/dev/null 2>&1; then
    status="healthy"
    message="tcp connect ok"
  fi
fi

if $json; then
  printf '{"engine":"elasticsearch","host":"%s","port":%s,"status":"%s","message":"%s"}\n' \
    "$host" "$port" "$status" "$message"
else
  printf 'engine: elasticsearch\n'
  printf 'host: %s\n' "$host"
  printf 'port: %s\n' "$port"
  printf 'status: %s\n' "$status"
  printf 'message: %s\n' "$message"
fi

if $strict && [[ "$status" != "healthy" ]]; then
  exit 1
fi

exit 0
