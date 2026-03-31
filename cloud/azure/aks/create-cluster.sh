#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: create-cluster.sh [OPTIONS]

Create an Azure Kubernetes Service (AKS) cluster.

Options:
  --name NAME               Cluster name (required)
  --resource-group NAME     Resource group (required)
  --location LOCATION       Azure region
  --subscription ID         Subscription override
  --node-count N            Node count (default: 3)
  --node-vm-size SIZE       Node VM size (default: Standard_D4s_v5)
  --kubernetes-version VER  Kubernetes version
  --network-plugin NAME     azure|kubenet (default: azure)
  --generate-ssh-keys       Generate SSH keys if needed
  --dry-run                 Print az command without executing
  -h, --help                Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

run_cmd() {
  if $dry_run; then
    printf 'DRY-RUN:' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 0
  fi
  "$@"
}

name=""
resource_group=""
location=""
subscription=""
node_count=3
node_vm_size="Standard_D4s_v5"
kubernetes_version=""
network_plugin="azure"
generate_ssh_keys=false
dry_run=false

while (($#)); do
  case "$1" in
    --name)
      shift
      (($#)) || die "--name requires a value"
      name="$1"
      ;;
    --resource-group)
      shift
      (($#)) || die "--resource-group requires a value"
      resource_group="$1"
      ;;
    --location)
      shift
      (($#)) || die "--location requires a value"
      location="$1"
      ;;
    --subscription)
      shift
      (($#)) || die "--subscription requires a value"
      subscription="$1"
      ;;
    --node-count)
      shift
      (($#)) || die "--node-count requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--node-count must be a positive integer"
      node_count="$1"
      ;;
    --node-vm-size)
      shift
      (($#)) || die "--node-vm-size requires a value"
      node_vm_size="$1"
      ;;
    --kubernetes-version)
      shift
      (($#)) || die "--kubernetes-version requires a value"
      kubernetes_version="$1"
      ;;
    --network-plugin)
      shift
      (($#)) || die "--network-plugin requires a value"
      case "$1" in
        azure | kubenet) network_plugin="$1" ;;
        *) die "invalid --network-plugin value: $1" ;;
      esac
      ;;
    --generate-ssh-keys)
      generate_ssh_keys=true
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

command_exists az || die "az CLI is required but not found"
[[ -n "$name" ]] || die "--name is required"
[[ -n "$resource_group" ]] || die "--resource-group is required"

cmd=(az aks create --name "$name" --resource-group "$resource_group" --node-count "$node_count" --node-vm-size "$node_vm_size" --network-plugin "$network_plugin")
[[ -n "$location" ]] && cmd+=(--location "$location")
[[ -n "$subscription" ]] && cmd+=(--subscription "$subscription")
[[ -n "$kubernetes_version" ]] && cmd+=(--kubernetes-version "$kubernetes_version")
$generate_ssh_keys && cmd+=(--generate-ssh-keys)

run_cmd "${cmd[@]}"
