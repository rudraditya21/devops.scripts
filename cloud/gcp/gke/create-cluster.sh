#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: create-cluster.sh [OPTIONS]

Create a GKE cluster with validated defaults.

Options:
  --name NAME                 Cluster name (required)
  --zone ZONE                 Zonal cluster location
  --region REGION             Regional cluster location
  --project PROJECT           GCP project override
  --num-nodes N               Node count per zone (default: 3)
  --machine-type TYPE         Node machine type (default: e2-standard-4)
  --release-channel CHANNEL   rapid|regular|stable (default: regular)
  --network NAME              VPC network name
  --subnetwork NAME           Subnetwork name
  --async                     Return immediately after request
  --dry-run                   Print gcloud command without executing
  -h, --help                  Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

validate_name() {
  [[ "$1" =~ ^[a-z]([-a-z0-9]{0,38}[a-z0-9])?$ ]]
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

cluster_name=""
zone=""
region=""
project=""
num_nodes=3
machine_type="e2-standard-4"
release_channel="regular"
network=""
subnetwork=""
async_mode=false
dry_run=false

while (($#)); do
  case "$1" in
    --name)
      shift
      (($#)) || die "--name requires a value"
      validate_name "$1" || die "invalid cluster name: $1"
      cluster_name="$1"
      ;;
    --zone)
      shift
      (($#)) || die "--zone requires a value"
      zone="$1"
      ;;
    --region)
      shift
      (($#)) || die "--region requires a value"
      region="$1"
      ;;
    --project)
      shift
      (($#)) || die "--project requires a value"
      project="$1"
      ;;
    --num-nodes)
      shift
      (($#)) || die "--num-nodes requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--num-nodes must be a positive integer"
      num_nodes="$1"
      ;;
    --machine-type)
      shift
      (($#)) || die "--machine-type requires a value"
      machine_type="$1"
      ;;
    --release-channel)
      shift
      (($#)) || die "--release-channel requires a value"
      case "$1" in
        rapid | regular | stable) release_channel="$1" ;;
        *) die "invalid --release-channel value: $1" ;;
      esac
      ;;
    --network)
      shift
      (($#)) || die "--network requires a value"
      network="$1"
      ;;
    --subnetwork)
      shift
      (($#)) || die "--subnetwork requires a value"
      subnetwork="$1"
      ;;
    --async)
      async_mode=true
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

command_exists gcloud || die "gcloud is required but not found"
[[ -n "$cluster_name" ]] || die "--name is required"

if [[ -n "$zone" && -n "$region" ]]; then
  die "use either --zone or --region, not both"
fi
if [[ -z "$zone" && -z "$region" ]]; then
  die "one of --zone or --region is required"
fi

cmd=(gcloud container clusters create "$cluster_name" --num-nodes "$num_nodes" --machine-type "$machine_type" --release-channel "$release_channel")

[[ -n "$zone" ]] && cmd+=(--zone "$zone")
[[ -n "$region" ]] && cmd+=(--region "$region")
[[ -n "$project" ]] && cmd+=(--project "$project")
[[ -n "$network" ]] && cmd+=(--network "$network")
[[ -n "$subnetwork" ]] && cmd+=(--subnetwork "$subnetwork")
$async_mode && cmd+=(--async)

run_cmd "${cmd[@]}"
