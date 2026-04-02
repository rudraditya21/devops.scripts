#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: install.sh [OPTIONS]

Install sentry monitoring components.

Options:
  --version VALUE      Version to record (default: latest)
  --channel NAME       Release channel (default: stable)
  --install-dir PATH   Install directory (default: /opt/sentry)
  --config-dir PATH    Config directory (default: /etc/sentry)
  --bin-dir PATH       Binary directory (default: /usr/local/bin)
  --dry-run            Print actions without writing files
  -h, --help           Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

version="latest"
channel="stable"
install_dir="/opt/sentry"
config_dir="/etc/sentry"
bin_dir="/usr/local/bin"
dry_run=false

while (($#)); do
  case "$1" in
    --version) shift; (($#)) || die "--version requires a value"; version="$1" ;;
    --channel) shift; (($#)) || die "--channel requires a value"; channel="$1" ;;
    --install-dir) shift; (($#)) || die "--install-dir requires a value"; install_dir="$1" ;;
    --config-dir) shift; (($#)) || die "--config-dir requires a value"; config_dir="$1" ;;
    --bin-dir) shift; (($#)) || die "--bin-dir requires a value"; bin_dir="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

if $dry_run; then
  printf 'DRY-RUN: mkdir -p %s %s %s\n' "$install_dir" "$config_dir" "$bin_dir"
  printf 'DRY-RUN: write install receipt for sentry version=%s channel=%s\n' "$version" "$channel"
  exit 0
fi

mkdir -p "$install_dir" "$config_dir" "$bin_dir"
cat > "$install_dir/INSTALL_RECEIPT" <<RECEIPT
stack=sentry
version=$version
channel=$channel
installed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
install_dir=$install_dir
config_dir=$config_dir
bin_dir=$bin_dir
RECEIPT

printf 'Installed sentry metadata at %s\n' "$install_dir/INSTALL_RECEIPT"
exit 0
