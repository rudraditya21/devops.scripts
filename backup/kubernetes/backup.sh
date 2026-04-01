#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: backup.sh [OPTIONS]

Create a kubernetes backup artifact.

Options:
  --source PATH          Source path to back up (required)
  --output PATH          Output artifact path (required)
  --compress             Create tar.gz archive (default: true)
  --no-compress          Copy source as-is when possible
  --metadata KV          Metadata key=value entry (repeatable)
  --dry-run              Print actions without executing
  -h, --help             Show help
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

sha256_cmd() {
  if command -v sha256sum > /dev/null 2>&1; then
    printf 'sha256sum'
  elif command -v shasum > /dev/null 2>&1; then
    printf 'shasum -a 256'
  else
    return 1
  fi
}

source_path=""
output_path=""
compress=true
dry_run=false
metadata=()

while (($#)); do
  case "$1" in
    --source) shift; (($#)) || die "--source requires a value"; source_path="$1" ;;
    --output) shift; (($#)) || die "--output requires a value"; output_path="$1" ;;
    --compress) compress=true ;;
    --no-compress) compress=false ;;
    --metadata) shift; (($#)) || die "--metadata requires a value"; metadata+=("$1") ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$source_path" ]] || die "--source is required"
[[ -n "$output_path" ]] || die "--output is required"
[[ -e "$source_path" ]] || die "source path does not exist: $source_path"

run_cmd mkdir -p "$(dirname "$output_path")"

if $compress; then
  run_cmd tar -czf "$output_path" -C "$(dirname "$source_path")" "$(basename "$source_path")"
else
  if [[ -d "$source_path" ]]; then
    run_cmd mkdir -p "$output_path"
    run_cmd cp -a "$source_path/." "$output_path/"
  else
    run_cmd cp -a "$source_path" "$output_path"
  fi
fi

checksum_tool="$(sha256_cmd || true)"
if [[ -n "$checksum_tool" ]]; then
  if $dry_run; then
    printf 'DRY-RUN: create checksum file %s.sha256\n' "$output_path" >&2
  else
    # shellcheck disable=SC2086
    $checksum_tool "$output_path" > "$output_path.sha256"
  fi
fi

if $dry_run; then
  printf 'DRY-RUN: write metadata file %s.meta\n' "$output_path" >&2
else
  {
    printf 'category=kubernetes\n'
    printf 'created_at=%s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)"
    printf 'source=%s\n' "$source_path"
    printf 'compress=%s\n' "$compress"
    for kv in "${metadata[@]}"; do
      printf 'meta.%s\n' "$kv"
    done
  } > "$output_path.meta"
fi

exit 0
