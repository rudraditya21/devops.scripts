#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: example.sh [OPTIONS] [-- COMMAND [ARGS...]]

Run retry wrapper examples using shared/safety/retry.sh.

Options:
  --attempts N      Total attempts (default: 3)
  --delay SEC       Initial retry delay (default: 1)
  --backoff FACTOR  Delay multiplier (default: 2)
  --max-delay SEC   Delay cap (default: 0)
  --jitter PERCENT  Positive jitter percent (default: 0)
  --retry-on CODES  Comma-separated retry status codes
  --quiet           Suppress retry logs
  -h, --help        Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

attempts="3"
delay="1"
backoff="2"
max_delay="0"
jitter="0"
retry_on=""
quiet=false
command=(bash -lc 'echo retry example command executed')

while (($#)); do
  case "$1" in
    --attempts)
      shift
      (($#)) || die "--attempts requires a value"
      attempts="$1"
      ;;
    --delay)
      shift
      (($#)) || die "--delay requires a value"
      delay="$1"
      ;;
    --backoff)
      shift
      (($#)) || die "--backoff requires a value"
      backoff="$1"
      ;;
    --max-delay)
      shift
      (($#)) || die "--max-delay requires a value"
      max_delay="$1"
      ;;
    --jitter)
      shift
      (($#)) || die "--jitter requires a value"
      jitter="$1"
      ;;
    --retry-on)
      shift
      (($#)) || die "--retry-on requires a value"
      retry_on="$1"
      ;;
    --quiet)
      quiet=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      ((${#@} > 0)) || die "COMMAND is required after --"
      command=("$@")
      break
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
  shift
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
retry_script="$repo_root/shared/safety/retry.sh"

[[ -x "$retry_script" ]] || die "missing dependency: $retry_script"

run=(bash "$retry_script" --attempts "$attempts" --delay "$delay" --backoff "$backoff" --max-delay "$max_delay" --jitter "$jitter")
[[ -n "$retry_on" ]] && run+=(--retry-on "$retry_on")
$quiet && run+=(--quiet)
run+=(-- "${command[@]}")

"${run[@]}"
