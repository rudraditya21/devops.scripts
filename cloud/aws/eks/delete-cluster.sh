#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: delete-cluster.sh [OPTIONS]

Delete an EKS cluster, optionally deleting nodegroups first.

Options:
  --name NAME             Cluster name (required)
  --delete-nodegroups     Delete all nodegroups before deleting cluster
  --if-missing            Return success when cluster does not exist
  --wait                  Wait for delete completion (default)
  --no-wait               Return immediately after delete call
  --timeout SEC           Wait timeout (default: 1800)
  --poll-interval SEC     Wait poll interval (default: 20)
  --region REGION         AWS region
  --profile PROFILE       AWS profile
  --yes                   Required for non-dry-run deletion
  --dry-run               Print planned commands only
  -h, --help              Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [delete-cluster] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

validate_cluster_name() {
  [[ "$1" =~ ^[0-9A-Za-z][A-Za-z0-9_-]{0,99}$ ]]
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

cluster_exists() {
  aws "${aws_options[@]}" eks describe-cluster --name "$cluster_name" > /dev/null 2>&1
}

wait_for_nodegroup_deleted() {
  local nodegroup_name="$1"
  local start_time elapsed
  start_time="$(date +%s)"

  while true; do
    if ! aws "${aws_options[@]}" eks describe-nodegroup --cluster-name "$cluster_name" --nodegroup-name "$nodegroup_name" > /dev/null 2>&1; then
      return 0
    fi

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for nodegroup deletion: $nodegroup_name"
    fi

    sleep "$poll_interval_seconds"
  done
}

wait_for_cluster_deleted() {
  local start_time elapsed
  start_time="$(date +%s)"

  while true; do
    if ! cluster_exists; then
      return 0
    fi

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for cluster deletion: $cluster_name"
    fi

    sleep "$poll_interval_seconds"
  done
}

cluster_name=""
delete_nodegroups=false
if_missing=false
wait_enabled=true
timeout_seconds=1800
poll_interval_seconds=20
region=""
profile=""
yes=false
dry_run=false

while (($#)); do
  case "$1" in
    --name)
      shift
      (($#)) || die "--name requires a value"
      validate_cluster_name "$1" || die "invalid cluster name: $1"
      cluster_name="$1"
      ;;
    --delete-nodegroups)
      delete_nodegroups=true
      ;;
    --if-missing)
      if_missing=true
      ;;
    --wait)
      wait_enabled=true
      ;;
    --no-wait)
      wait_enabled=false
      ;;
    --timeout)
      shift
      (($#)) || die "--timeout requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--timeout must be a positive integer"
      timeout_seconds="$1"
      ;;
    --poll-interval)
      shift
      (($#)) || die "--poll-interval requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--poll-interval must be a positive integer"
      poll_interval_seconds="$1"
      ;;
    --region)
      shift
      (($#)) || die "--region requires a value"
      region="$1"
      ;;
    --profile)
      shift
      (($#)) || die "--profile requires a value"
      profile="$1"
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

[[ -n "$cluster_name" ]] || die "--name is required"
command_exists aws || die "aws CLI is required but not found"
if ! $dry_run && ! $yes; then
  die "--yes is required for deletion"
fi

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

if ! cluster_exists; then
  if $if_missing; then
    log "cluster not found, skipping: $cluster_name"
    exit 0
  fi
  die "cluster not found: $cluster_name"
fi

if $delete_nodegroups; then
  while read -r ng; do
    [[ -n "$ng" ]] || continue
    run_cmd aws "${aws_options[@]}" eks delete-nodegroup --cluster-name "$cluster_name" --nodegroup-name "$ng" > /dev/null
    log "nodegroup delete requested: $ng"
    if $wait_enabled && ! $dry_run; then
      wait_for_nodegroup_deleted "$ng"
      log "nodegroup deleted: $ng"
    fi
  done < <(aws "${aws_options[@]}" eks list-nodegroups --cluster-name "$cluster_name" --query 'nodegroups' --output text | tr '\t' '\n')
fi

run_cmd aws "${aws_options[@]}" eks delete-cluster --name "$cluster_name" > /dev/null
log "cluster delete requested: $cluster_name"

if $wait_enabled && ! $dry_run; then
  wait_for_cluster_deleted
  log "cluster deleted: $cluster_name"
fi

exit 0
