#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: healthcheck.sh [OPTIONS]

Run runtime-policy security healthcheck.

Options:
  --target HOST           Hostname or IP (default: 127.0.0.1)
  --port N                TCP port (default: 9090)
  --timeout N             Timeout seconds (default: 3)
  --json                  Emit JSON output
  --strict                Exit non-zero on unhealthy status
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

target="127.0.0.1"
port="9090"
timeout_sec="3"
json=false
strict=false

while (($#)); do
  case "$1" in
    --target) shift; (($#)) || die "--target requires a value"; target="$1" ;;
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
  if nc -z -w "$timeout_sec" "$target" "$port" >/dev/null 2>&1; then
    status="healthy"
    message="tcp connect ok"
  fi
elif command -v timeout >/dev/null 2>&1; then
  if timeout "$timeout_sec" bash -c "</dev/tcp/$target/$port" >/dev/null 2>&1; then
    status="healthy"
    message="tcp connect ok"
  fi
fi

if $json; then
  printf '{"domain":"runtime-policy","target":"%s","port":%s,"status":"%s","message":"%s"}\n' "$target" "$port" "$status" "$message"
else
  printf 'domain: runtime-policy\n'
  printf 'target: %s\n' "$target"
  printf 'port: %s\n' "$port"
  printf 'status: %s\n' "$status"
  printf 'message: %s\n' "$message"
fi

if $strict && [[ "$status" != "healthy" ]]; then
  exit 1
fi

exit 0
