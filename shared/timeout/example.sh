#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: example.sh [OPTIONS] [-- COMMAND [ARGS...]]

Run timeout wrapper examples using shared/safety/with-timeout.sh.

Options:
  --timeout SEC      Command timeout in seconds (default: 5)
  --signal SIGNAL    Signal sent at timeout (default: TERM)
  --grace SEC        Grace period before SIGKILL (default: 1)
  --quiet            Suppress timeout logs
  -h, --help         Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

timeout_sec="5"
signal_name="TERM"
grace_sec="1"
quiet=false
command=(bash -lc 'sleep 1; echo timeout example command completed')

while (($#)); do
  case "$1" in
    --timeout)
      shift
      (($#)) || die "--timeout requires a value"
      timeout_sec="$1"
      ;;
    --signal)
      shift
      (($#)) || die "--signal requires a value"
      signal_name="$1"
      ;;
    --grace)
      shift
      (($#)) || die "--grace requires a value"
      grace_sec="$1"
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
with_timeout_script="$repo_root/shared/safety/with-timeout.sh"

[[ -x "$with_timeout_script" ]] || die "missing dependency: $with_timeout_script"

run=(bash "$with_timeout_script" --timeout "$timeout_sec" --signal "$signal_name" --grace "$grace_sec")
$quiet && run+=(--quiet)
run+=(-- "${command[@]}")

"${run[@]}"
