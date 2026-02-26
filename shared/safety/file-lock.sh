#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: file-lock.sh --lock-file PATH [OPTIONS] -- COMMAND [ARGS...]

Acquire an exclusive lock using an atomic directory and run a command.

Options:
  --lock-file PATH      Lock directory path (required)
  --timeout SEC         Max wait time in seconds (default: 0, wait forever)
  --poll-interval SEC   Poll interval while waiting (default: 0.2)
  --stale-after SEC     Break stale lock older than SEC (default: 0, disabled)
  --quiet               Suppress wait/stale logs
  -h, --help            Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  if ! $quiet; then
    printf '%s [file-lock] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
  fi
}

is_non_negative_number() {
  [[ "$1" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]
}

is_non_negative_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

get_mtime() {
  local path="$1"
  if stat -f '%m' "$path" > /dev/null 2>&1; then
    stat -f '%m' "$path"
  else
    stat -c '%Y' "$path"
  fi
}

is_process_alive() {
  local pid="$1"
  kill -0 "$pid" 2> /dev/null
}

lock_file=""
timeout="0"
poll_interval="0.2"
stale_after="0"
quiet=false
command=()

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
      is_non_negative_integer "$1" || die "--timeout must be a non-negative integer"
      timeout="$1"
      ;;
    --poll-interval)
      shift
      (($#)) || die "--poll-interval requires a value"
      is_non_negative_number "$1" || die "--poll-interval must be a non-negative number"
      poll_interval="$1"
      ;;
    --stale-after)
      shift
      (($#)) || die "--stale-after requires a value"
      is_non_negative_integer "$1" || die "--stale-after must be a non-negative integer"
      stale_after="$1"
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

[[ -n "$lock_file" ]] || die "--lock-file is required"
((${#command[@]} > 0)) || die "COMMAND is required (use -- COMMAND ...)"

lock_path="$lock_file"
metadata_file="${lock_path}/.owner"
lock_acquired=false

# shellcheck disable=SC2329
release_lock() {
  if $lock_acquired; then
    rm -rf -- "$lock_path" || true
  fi
}

trap release_lock EXIT INT TERM HUP

write_metadata() {
  {
    printf 'pid=%s\n' "$$"
    printf 'created=%s\n' "$(date +%s)"
    printf 'host=%s\n' "$(hostname 2> /dev/null || printf unknown)"
  } > "$metadata_file"
}

lock_is_stale() {
  ((stale_after > 0)) || return 1
  [[ -e "$lock_path" ]] || return 1

  local now mtime age owner_pid
  now="$(date +%s)"
  mtime="$(get_mtime "$lock_path" 2> /dev/null || printf '0')"
  age=$((now - mtime))

  owner_pid=""
  if [[ -r "$metadata_file" ]]; then
    owner_pid="$(awk -F= '$1=="pid"{print $2}' "$metadata_file" | tr -d '[:space:]')"
  fi

  if [[ -n "$owner_pid" ]] && is_process_alive "$owner_pid"; then
    return 1
  fi

  ((age >= stale_after))
}

start_ts="$(date +%s)"

while true; do
  if mkdir "$lock_path" 2> /dev/null; then
    lock_acquired=true
    write_metadata
    break
  fi

  if lock_is_stale; then
    log "detected stale lock at $lock_path, removing"
    rm -rf -- "$lock_path" || die "failed to remove stale lock: $lock_path"
    continue
  fi

  if ((timeout > 0)); then
    now_ts="$(date +%s)"
    elapsed=$((now_ts - start_ts))
    if ((elapsed >= timeout)); then
      printf 'ERROR: timed out waiting for lock: %s\n' "$lock_path" >&2
      exit 73
    fi
  fi

  log "waiting for lock: $lock_path"
  sleep "$poll_interval"
done

log "acquired lock: $lock_path"
set +e
"${command[@]}"
status=$?
set -e

exit "$status"
