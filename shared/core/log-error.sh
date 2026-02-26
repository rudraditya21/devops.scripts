#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'EOF'
Usage: log-error.sh [--tag TAG] [--timestamp-format FORMAT] [--stream stdout|stderr] [--exit-code CODE] MESSAGE...

Logs an ERROR message with timestamp and tag.
Optionally exits with CODE after logging.
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

tag="${LOG_TAG:-$(basename "$0" .sh)}"
timestamp_format="${LOG_TIMESTAMP_FORMAT:-%Y-%m-%dT%H:%M:%S%z}"
stream="stderr"
exit_code=""

while (($#)); do
  case "$1" in
    --tag)
      shift
      (($#)) || die "--tag requires a value"
      tag="$1"
      ;;
    --timestamp-format)
      shift
      (($#)) || die "--timestamp-format requires a value"
      timestamp_format="$1"
      ;;
    --stream)
      shift
      (($#)) || die "--stream requires a value"
      case "$1" in
        stdout | stderr) stream="$1" ;;
        *) die "invalid stream: $1 (expected stdout or stderr)" ;;
      esac
      ;;
    --exit-code)
      shift
      (($#)) || die "--exit-code requires a value"
      [[ "$1" =~ ^[0-9]+$ ]] || die "exit code must be numeric"
      (("$1" <= 255)) || die "exit code must be <= 255"
      exit_code="$1"
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
      break
      ;;
  esac
  shift
done

(($#)) || die "MESSAGE is required"
message="$*"
timestamp="$(date +"$timestamp_format")" || die "failed to format timestamp"

if [[ "$stream" == "stdout" ]]; then
  printf '%s [ERROR] [%s] %s\n' "$timestamp" "$tag" "$message"
else
  printf '%s [ERROR] [%s] %s\n' "$timestamp" "$tag" "$message" >&2
fi

if [[ -n "$exit_code" ]]; then
  exit "$exit_code"
fi
