#!/usr/bin/env bash
set -euo pipefail

usage(){ cat << 'USAGE'
Usage: cleanup.sh [OPTIONS]

Clean local Kubernetes workstation caches.

Options:
  --kube-cache-dir DIR    Kube cache dir (default: ~/.kube/cache)
  --helm-cache-dir DIR    Helm cache dir (default: ~/.cache/helm)
  --dry-run               Print actions without executing
  -h, --help              Show help
USAGE
}

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 2; }
run_cmd(){ if $dry_run; then printf 'DRY-RUN:' >&2; printf ' %q' "$@" >&2; printf '\n' >&2; return 0; fi; "$@"; }
remove_path(){ local p="$1"; [[ -d "$p" ]] || return 0; run_cmd rm -rf -- "$p"; }

kube_cache="$HOME/.kube/cache"
helm_cache="$HOME/.cache/helm"
dry_run=false

while (($#)); do
  case "$1" in
    --kube-cache-dir) shift; (($#)) || die "--kube-cache-dir requires a value"; kube_cache="$1" ;;
    --helm-cache-dir) shift; (($#)) || die "--helm-cache-dir requires a value"; helm_cache="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

remove_path "$kube_cache"
remove_path "$helm_cache"
exit 0
