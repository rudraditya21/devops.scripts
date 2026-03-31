#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: delete-cluster.sh [OPTIONS]

Delete a GKE cluster.

Options:
  --name NAME           Cluster name (required)
  --zone ZONE           Cluster zone
  --region REGION       Cluster region
  --project PROJECT     GCP project override
  --async               Return immediately after request
  --yes                 Required for non-dry-run deletion
  --dry-run             Print gcloud command without executing
  -h, --help            Show help
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

cluster_name=""
zone=""
region=""
project=""
async_mode=false
yes=false
dry_run=false

while (($#)); do
  case "$1" in
    --name)
      shift
      (($#)) || die "--name requires a value"
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
    --async)
      async_mode=true
      ;;
    --yes)
      yes=true
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
if ! $dry_run && ! $yes; then
  die "--yes is required for deletion"
fi

cmd=(gcloud container clusters delete "$cluster_name" --quiet)
[[ -n "$zone" ]] && cmd+=(--zone "$zone")
[[ -n "$region" ]] && cmd+=(--region "$region")
[[ -n "$project" ]] && cmd+=(--project "$project")
$async_mode && cmd+=(--async)

run_cmd "${cmd[@]}"
