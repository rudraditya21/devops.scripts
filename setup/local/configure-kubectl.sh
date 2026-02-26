#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: configure-kubectl.sh [OPTIONS]

Configure local kubectl context and namespace defaults.

Options:
  --kubeconfig PATH     Target kubeconfig file (default: ~/.kube/config)
  --context NAME        Context to activate
  --namespace NAME      Namespace to set on context/current context
  --dry-run             Print commands without executing
  -h, --help            Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [configure-kubectl] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

run_cmd() {
  if $dry_run; then
    printf 'DRY-RUN: %s\n' "$*" >&2
    return 0
  fi
  "$@"
}

ensure_kubectl() {
  command -v kubectl > /dev/null 2>&1 || die "kubectl is required but not found"
}

kubeconfig_path="$HOME/.kube/config"
context_name=""
namespace_name=""
dry_run=false

while (($#)); do
  case "$1" in
    --kubeconfig)
      shift
      (($#)) || die "--kubeconfig requires a value"
      kubeconfig_path="$1"
      ;;
    --context)
      shift
      (($#)) || die "--context requires a value"
      context_name="$1"
      ;;
    --namespace)
      shift
      (($#)) || die "--namespace requires a value"
      namespace_name="$1"
      ;;
    --dry-run)
      dry_run=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
  shift
done

ensure_kubectl
if $dry_run; then
  if [[ ! -f "$kubeconfig_path" ]]; then
    log "dry-run: create $(dirname "$kubeconfig_path") and $kubeconfig_path"
  fi
else
  mkdir -p "$(dirname "$kubeconfig_path")"
  if [[ ! -f "$kubeconfig_path" ]]; then
    : > "$kubeconfig_path"
    chmod 600 "$kubeconfig_path"
  fi
fi

if [[ -n "$context_name" ]]; then
  run_cmd kubectl config use-context "$context_name" --kubeconfig "$kubeconfig_path"
fi

if [[ -n "$namespace_name" ]]; then
  if [[ -n "$context_name" ]]; then
    run_cmd kubectl config set-context "$context_name" --namespace "$namespace_name" --kubeconfig "$kubeconfig_path"
  else
    run_cmd kubectl config set-context --current --namespace "$namespace_name" --kubeconfig "$kubeconfig_path"
  fi
fi

log "kubectl configuration applied"
