#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: configure.sh [OPTIONS]

Generate zabbix configuration.

Options:
  --config-file PATH   Output configuration path (required)
  --endpoint URL       Service endpoint (default: http://localhost)
  --namespace NAME     Namespace label (default: default)
  --retention VALUE    Retention window (default: 30d)
  --scrape-interval S  Scrape interval (default: 30s)
  --dry-run            Print generated config only
  -h, --help           Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

config_file=""
endpoint="http://localhost"
namespace="default"
retention="30d"
scrape_interval="30s"
dry_run=false

while (($#)); do
  case "$1" in
    --config-file) shift; (($#)) || die "--config-file requires a value"; config_file="$1" ;;
    --endpoint) shift; (($#)) || die "--endpoint requires a value"; endpoint="$1" ;;
    --namespace) shift; (($#)) || die "--namespace requires a value"; namespace="$1" ;;
    --retention) shift; (($#)) || die "--retention requires a value"; retention="$1" ;;
    --scrape-interval) shift; (($#)) || die "--scrape-interval requires a value"; scrape_interval="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$config_file" ]] || die "--config-file is required"

config_payload=$(cat <<CFG
stack: zabbix
endpoint: $endpoint
namespace: $namespace
retention: $retention
scrape_interval: $scrape_interval
CFG
)

if $dry_run; then
  printf 'DRY-RUN: write configuration to %s\n' "$config_file"
  printf '%s\n' "$config_payload"
  exit 0
fi

mkdir -p "$(dirname "$config_file")"
printf '%s\n' "$config_payload" > "$config_file"
printf 'Wrote zabbix config to %s\n' "$config_file"
exit 0
