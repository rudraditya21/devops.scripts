#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: install.sh [OPTIONS]

Install Kubernetes workstation tools.

Options:
  --manager NAME      Package manager override (auto|brew|apt|dnf|yum, default: auto)
  --yes               Non-interactive install mode
  --dry-run           Print actions without executing
  --update-cache      Refresh package metadata
  -h, --help          Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
installer="$repo_root/setup/local/install-cli-tools.sh"

[[ -x "$installer" ]] || die "required installer missing: $installer"

manager="auto"
yes=false
dry_run=false
update_cache=false

while (($#)); do
  case "$1" in
    --manager) shift; (($#)) || die "--manager requires a value"; manager="$1" ;;
    --yes) yes=true ;;
    --dry-run) dry_run=true ;;
    --update-cache) update_cache=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

cmd=(bash "$installer" --manager "$manager" --tools kubectl,helm)
$yes && cmd+=(--yes)
$dry_run && cmd+=(--dry-run)
$update_cache && cmd+=(--update-cache)

"${cmd[@]}"
