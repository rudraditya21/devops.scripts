#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: example.sh [OPTIONS] [-- COMMAND [ARGS...]]

Run lock wrapper examples using shared/safety/file-lock.sh.

Options:
  --lock-file PATH      Lock directory path (default: /tmp/devops-scripts-example.lock)
  --timeout SEC         Max wait time in seconds (default: 5)
  --poll-interval SEC   Poll interval while waiting (default: 0.2)
  --stale-after SEC     Break stale lock older than SEC (default: 0)
  --quiet               Suppress lock logs
  -h, --help            Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

lock_file="/tmp/devops-scripts-example.lock"
timeout_sec="5"
poll_interval="0.2"
stale_after="0"
quiet=false
command=(bash -lc 'echo lock example command executed')

while (($#)); do
  case "$1" in
    --lock-file)
      shift
      (($#)) || die "--lock-file requires a value"
      lock_file="$1"
      ;;
    --timeout)
      shift
      (($#)) || die "--timeout requires a value"
      timeout_sec="$1"
      ;;
    --poll-interval)
      shift
      (($#)) || die "--poll-interval requires a value"
      poll_interval="$1"
      ;;
    --stale-after)
      shift
      (($#)) || die "--stale-after requires a value"
      stale_after="$1"
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
file_lock_script="$repo_root/shared/safety/file-lock.sh"

[[ -x "$file_lock_script" ]] || die "missing dependency: $file_lock_script"

run=(bash "$file_lock_script" --lock-file "$lock_file" --timeout "$timeout_sec" --poll-interval "$poll_interval" --stale-after "$stale_after")
$quiet && run+=(--quiet)
run+=(-- "${command[@]}")

"${run[@]}"
