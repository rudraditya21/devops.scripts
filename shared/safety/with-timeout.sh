#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: with-timeout.sh --timeout SEC [OPTIONS] -- COMMAND [ARGS...]

Run a command and enforce a maximum runtime.

Options:
  --timeout SEC        Timeout in seconds (required, supports decimals)
  --signal SIGNAL      Signal sent at timeout (default: TERM)
  --grace SEC          Grace period before SIGKILL (default: 5)
  --quiet              Suppress timeout logs
  -h, --help           Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  if ! $quiet; then
    printf '%s [with-timeout] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
  fi
}

is_positive_number() {
  [[ "$1" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]] && awk -v n="$1" 'BEGIN { exit !(n > 0) }'
}

is_non_negative_number() {
  [[ "$1" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]
}

timeout=""
signal_name="TERM"
grace="5"
quiet=false
command=()

while (($#)); do
  case "$1" in
    --timeout)
      shift
      (($#)) || die "--timeout requires a value"
      is_positive_number "$1" || die "--timeout must be > 0"
      timeout="$1"
      ;;
    --signal)
      shift
      (($#)) || die "--signal requires a value"
      kill -l "$1" > /dev/null 2>&1 || die "invalid signal: $1"
      signal_name="$1"
      ;;
    --grace)
      shift
      (($#)) || die "--grace requires a value"
      is_non_negative_number "$1" || die "--grace must be >= 0"
      grace="$1"
      ;;
    --quiet)
      quiet=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      command=("$@")
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      command=("$@")
      break
      ;;
  esac
  shift
done

[[ -n "$timeout" ]] || die "--timeout is required"
((${#command[@]} > 0)) || die "COMMAND is required (use -- COMMAND ...)"

marker_file="$(mktemp "${TMPDIR:-/tmp}/with-timeout.XXXXXX")"
child_pid=""
watchdog_pid=""

# shellcheck disable=SC2329
cleanup() {
  [[ -n "$watchdog_pid" ]] && kill "$watchdog_pid" 2> /dev/null || true
  [[ -n "$watchdog_pid" ]] && wait "$watchdog_pid" 2> /dev/null || true
  rm -f "$marker_file"
}
trap cleanup EXIT

"${command[@]}" &
child_pid="$!"

(
  sleep "$timeout"
  if kill -0 "$child_pid" 2> /dev/null; then
    printf 'timeout\n' > "$marker_file"
    kill -s "$signal_name" "$child_pid" 2> /dev/null || true

    if awk -v g="$grace" 'BEGIN { exit !(g > 0) }'; then
      sleep "$grace"
      if kill -0 "$child_pid" 2> /dev/null; then
        kill -9 "$child_pid" 2> /dev/null || true
      fi
    fi
  fi
) &
watchdog_pid="$!"

set +e
wait "$child_pid"
command_status=$?
set -e

if [[ -s "$marker_file" ]]; then
  log "command timed out after ${timeout}s"
  exit 124
fi

exit "$command_status"
