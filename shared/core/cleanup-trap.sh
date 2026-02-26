#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'EOF'
Usage: cleanup-trap.sh --cleanup "CMD" [--cleanup "CMD"...] [--cleanup-file FILE] [--verbose] -- COMMAND [ARGS...]

Runs COMMAND and executes cleanup commands in reverse order after it exits,
including when interrupted by INT/TERM/HUP.

Exit code:
  - COMMAND exit code, unless cleanup fails while COMMAND succeeded
  - 70 if cleanup fails and COMMAND exit code is 0
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  local level="$1"
  shift
  local ts
  ts="$(date +"%Y-%m-%dT%H:%M:%S%z")"
  printf '%s [%s] [cleanup-trap] %s\n' "$ts" "$level" "$*" >&2
}

trim_line() {
  printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

cleanup_commands=()
verbose=false

while (($#)); do
  case "$1" in
    --cleanup)
      shift
      (($#)) || die "--cleanup requires a command string"
      cleanup_commands+=("$1")
      ;;
    --cleanup-file)
      shift
      (($#)) || die "--cleanup-file requires a file path"
      [[ -r "$1" ]] || die "cleanup file is not readable: $1"
      while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(trim_line "$line")"
        [[ -n "$line" ]] || continue
        [[ "$line" == \#* ]] && continue
        cleanup_commands+=("$line")
      done < "$1"
      ;;
    --verbose)
      verbose=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      die "unexpected argument before --: $1"
      ;;
  esac
  shift
done

((${#cleanup_commands[@]} > 0)) || die "at least one cleanup command is required"
(($# > 0)) || die "COMMAND is required after --"

command_to_run=("$@")
cleanup_failed=0
cleanup_done=0
child_pid=""

run_cleanup() {
  if ((cleanup_done == 1)); then
    return
  fi
  cleanup_done=1

  local i cmd
  for ((i = ${#cleanup_commands[@]} - 1; i >= 0; i--)); do
    cmd="${cleanup_commands[$i]}"
    if $verbose; then
      log "INFO" "running cleanup: $cmd"
    fi
    if ! bash -c "$cmd"; then
      cleanup_failed=1
      log "WARN" "cleanup command failed: $cmd"
    fi
  done
}

# shellcheck disable=SC2329
handle_signal() {
  local signal_name="$1"
  local exit_code="$2"

  if $verbose; then
    log "WARN" "received signal ${signal_name}; terminating command"
  fi

  if [[ -n "$child_pid" ]]; then
    kill "$child_pid" 2> /dev/null || true
    wait "$child_pid" 2> /dev/null || true
  fi

  run_cleanup

  if ((cleanup_failed != 0)); then
    exit 70
  fi
  exit "$exit_code"
}

trap 'handle_signal INT 130' INT
trap 'handle_signal TERM 143' TERM
trap 'handle_signal HUP 129' HUP

"${command_to_run[@]}" &
child_pid="$!"

set +e
wait "$child_pid"
command_status=$?
set -e

run_cleanup

if ((cleanup_failed != 0 && command_status == 0)); then
  exit 70
fi

exit "$command_status"
