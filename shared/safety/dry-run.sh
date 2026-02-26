#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: dry-run.sh [--dry-run|--execute] [--prefix TEXT] [--quiet] -- COMMAND [ARGS...]

Execute a command or print it without running, based on dry-run mode.

Options:
  --dry-run            Force dry-run mode
  --execute            Force execution mode
  --prefix TEXT        Prefix for dry-run message (default: DRY-RUN)
  --quiet              Suppress dry-run message output
  -h, --help           Show help

Environment:
  DRY_RUN              If set to 1/true/yes/on, dry-run is enabled by default.
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

normalize_bool() {
  case "${1:-}" in
    1 | true | TRUE | yes | YES | on | ON) return 0 ;;
    0 | false | FALSE | no | NO | off | OFF | "") return 1 ;;
    *) return 1 ;;
  esac
}

quote_command() {
  local out=""
  local arg
  for arg in "$@"; do
    if [[ -n "$out" ]]; then
      out+=" "
    fi
    out+="$(printf '%q' "$arg")"
  done
  printf '%s' "$out"
}

if normalize_bool "${DRY_RUN:-}"; then
  dry_run=true
else
  dry_run=false
fi

prefix="DRY-RUN"
quiet=false
command=()

while (($#)); do
  case "$1" in
    --dry-run)
      dry_run=true
      ;;
    --execute)
      dry_run=false
      ;;
    --prefix)
      shift
      (($#)) || die "--prefix requires a value"
      prefix="$1"
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

((${#command[@]} > 0)) || die "COMMAND is required (use -- COMMAND ...)"

if $dry_run; then
  if ! $quiet; then
    printf '%s: %s\n' "$prefix" "$(quote_command "${command[@]}")" >&2
  fi
  exit 0
fi

"${command[@]}"
