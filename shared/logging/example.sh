#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: example.sh [OPTIONS]

Run logging examples using shared/core logging primitives.

Options:
  --tag TAG            Log tag (default: logging-example)
  --stream STREAM      stdout|stderr (default: stderr)
  --info-message MSG   INFO message text
  --warn-message MSG   WARN message text
  --error-message MSG  ERROR message text
  --skip-error         Skip ERROR example line
  -h, --help           Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

tag="logging-example"
stream="stderr"
info_message="Logging info example"
warn_message="Logging warn example"
error_message="Logging error example"
skip_error=false

while (($#)); do
  case "$1" in
    --tag)
      shift
      (($#)) || die "--tag requires a value"
      tag="$1"
      ;;
    --stream)
      shift
      (($#)) || die "--stream requires a value"
      case "$1" in
        stdout|stderr) stream="$1" ;;
        *) die "invalid --stream value: $1" ;;
      esac
      ;;
    --info-message)
      shift
      (($#)) || die "--info-message requires a value"
      info_message="$1"
      ;;
    --warn-message)
      shift
      (($#)) || die "--warn-message requires a value"
      warn_message="$1"
      ;;
    --error-message)
      shift
      (($#)) || die "--error-message requires a value"
      error_message="$1"
      ;;
    --skip-error)
      skip_error=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
  shift
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

log_info="$repo_root/shared/core/log-info.sh"
log_warn="$repo_root/shared/core/log-warn.sh"
log_error="$repo_root/shared/core/log-error.sh"

[[ -x "$log_info" ]] || die "missing dependency: $log_info"
[[ -x "$log_warn" ]] || die "missing dependency: $log_warn"
[[ -x "$log_error" ]] || die "missing dependency: $log_error"

bash "$log_info" --tag "$tag" --stream "$stream" "$info_message"
bash "$log_warn" --tag "$tag" --stream "$stream" "$warn_message"

if ! $skip_error; then
  bash "$log_error" --tag "$tag" --stream "$stream" "$error_message"
fi
