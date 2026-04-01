#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: restore.sh [OPTIONS]

Restore a block-volume backup artifact.

Options:
  --input PATH            Backup artifact path (required)
  --target PATH           Restore target directory (required)
  --strip-components N    Strip leading path components when extracting archives (default: 0)
  --dry-run               Print actions without executing
  -h, --help              Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

run_cmd() {
  if $dry_run; then
    printf 'DRY-RUN:' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 0
  fi
  "$@"
}

input_path=""
target_path=""
strip_components="0"
dry_run=false

while (($#)); do
  case "$1" in
    --input) shift; (($#)) || die "--input requires a value"; input_path="$1" ;;
    --target) shift; (($#)) || die "--target requires a value"; target_path="$1" ;;
    --strip-components) shift; (($#)) || die "--strip-components requires a value"; [[ "$1" =~ ^[0-9]+$ ]] || die "--strip-components must be a non-negative integer"; strip_components="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$input_path" ]] || die "--input is required"
[[ -n "$target_path" ]] || die "--target is required"
[[ -e "$input_path" ]] || die "input path does not exist: $input_path"

run_cmd mkdir -p "$target_path"

case "$input_path" in
  *.tar.gz|*.tgz)
    run_cmd tar -xzf "$input_path" -C "$target_path" --strip-components "$strip_components"
    ;;
  *)
    if [[ -d "$input_path" ]]; then
      run_cmd cp -a "$input_path/." "$target_path/"
    else
      run_cmd cp -a "$input_path" "$target_path/"
    fi
    ;;
esac

exit 0
