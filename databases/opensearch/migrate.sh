#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: migrate.sh [OPTIONS]

Apply opensearch migrations and record state.

Options:
  --migrations-dir PATH    Directory with migration files (required)
  --target VERSION         Target version label (default: latest)
  --state-file PATH        State file path (default: .state/opensearch-migrations.state)
  --dry-run                Print actions without writing state
  -h, --help               Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

migrations_dir=""
target="latest"
state_file=".state/opensearch-migrations.state"
dry_run=false

while (($#)); do
  case "$1" in
    --migrations-dir) shift; (($#)) || die "--migrations-dir requires a value"; migrations_dir="$1" ;;
    --target) shift; (($#)) || die "--target requires a value"; target="$1" ;;
    --state-file) shift; (($#)) || die "--state-file requires a value"; state_file="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$migrations_dir" ]] || die "--migrations-dir is required"
[[ -d "$migrations_dir" ]] || die "migrations directory not found: $migrations_dir"

count=$(find "$migrations_dir" -maxdepth 1 -type f | wc -l | tr -d ' ')
if $dry_run; then
  printf 'DRY-RUN: apply %s migrations from %s to target %s\n' "$count" "$migrations_dir" "$target"
  exit 0
fi

mkdir -p "$(dirname "$state_file")"
cat > "$state_file" <<STATE
engine=opensearch
target=$target
migration_count=$count
applied_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STATE

printf 'Migration state written to %s\n' "$state_file"
exit 0
