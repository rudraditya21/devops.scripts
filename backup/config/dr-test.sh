#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: dr-test.sh [OPTIONS]

Run a disaster-recovery smoke test for config backups.

Options:
  --source PATH        Source path to test backup/restore against (required)
  --workdir DIR        Work directory (default: temp dir)
  --keep-workdir       Preserve work directory after test
  --dry-run            Print actions without executing
  -h, --help           Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

source_path=""
workdir=""
keep_workdir=false
dry_run=false

while (($#)); do
  case "$1" in
    --source) shift; (($#)) || die "--source requires a value"; source_path="$1" ;;
    --workdir) shift; (($#)) || die "--workdir requires a value"; workdir="$1" ;;
    --keep-workdir) keep_workdir=true ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$source_path" ]] || die "--source is required"
[[ -e "$source_path" ]] || die "source path does not exist: $source_path"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
backup_script="$script_dir/backup.sh"
restore_script="$script_dir/restore.sh"
verify_script="$script_dir/verify.sh"

[[ -x "$backup_script" ]] || die "missing script: $backup_script"
[[ -x "$restore_script" ]] || die "missing script: $restore_script"
[[ -x "$verify_script" ]] || die "missing script: $verify_script"

if [[ -z "$workdir" ]]; then
  workdir="$(mktemp -d "${TMPDIR:-/tmp}/config-dr-test.XXXXXX")"
else
  mkdir -p "$workdir"
fi

cleanup() {
  if ! $keep_workdir; then
    rm -rf "$workdir"
  fi
}
trap cleanup EXIT

artifact="$workdir/backup.tar.gz"
restore_target="$workdir/restore"

cmd_backup=(bash "$backup_script" --source "$source_path" --output "$artifact")
cmd_restore=(bash "$restore_script" --input "$artifact" --target "$restore_target")
cmd_verify=(bash "$verify_script" --backup "$artifact")

$dry_run && cmd_backup+=(--dry-run)
$dry_run && cmd_restore+=(--dry-run)

"${cmd_backup[@]}"
"${cmd_verify[@]}"
"${cmd_restore[@]}"

printf 'DR test completed for category: config\n'
printf 'workdir: %s\n' "$workdir"

exit 0
