#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: upgrade-cluster.sh [OPTIONS]

Upgrade EKS cluster control plane version.

Options:
  --name NAME          Cluster name (required)
  --version VERSION    Target Kubernetes version (required)
  --force              Force upgrade when AWS allows forced path
  --wait               Wait for update completion (default)
  --no-wait            Return after update API call
  --timeout SEC        Wait timeout (default: 3600)
  --poll-interval SEC  Wait poll interval (default: 20)
  --region REGION      AWS region
  --profile PROFILE    AWS profile
  --dry-run            Print planned commands only
  -h, --help           Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [upgrade-cluster] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
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

wait_for_update_success() {
  local update_id="$1"
  local start_time elapsed status
  start_time="$(date +%s)"

  while true; do
    status="$(aws "${aws_options[@]}" eks describe-update --name "$cluster_name" --update-id "$update_id" --query 'update.status' --output text 2> /dev/null || true)"
    case "$status" in
      Successful) return 0 ;;
      Failed | Cancelled) die "cluster update failed: $update_id (status=$status)" ;;
    esac

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for cluster update: $update_id"
    fi

    sleep "$poll_interval_seconds"
  done
}

wait_for_cluster_active_version() {
  local start_time elapsed status version
  start_time="$(date +%s)"

  while true; do
    status="$(aws "${aws_options[@]}" eks describe-cluster --name "$cluster_name" --query 'cluster.status' --output text 2> /dev/null || true)"
    version="$(aws "${aws_options[@]}" eks describe-cluster --name "$cluster_name" --query 'cluster.version' --output text 2> /dev/null || true)"
    if [[ "$status" == "ACTIVE" && "$version" == "$target_version" ]]; then
      return 0
    fi

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for cluster ACTIVE at version $target_version"
    fi

    sleep "$poll_interval_seconds"
  done
}

cluster_name=""
target_version=""
force_upgrade=false
wait_enabled=true
timeout_seconds=3600
poll_interval_seconds=20
region=""
profile=""
dry_run=false

while (($#)); do
  case "$1" in
    --name)
      shift
      (($#)) || die "--name requires a value"
      validate_cluster_name "$1" || die "invalid cluster name: $1"
      cluster_name="$1"
      ;;
    --version)
      shift
      (($#)) || die "--version requires a value"
      target_version="$1"
      ;;
    --force)
      force_upgrade=true
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
[[ -n "$target_version" ]] || die "--version is required"
command_exists aws || die "aws CLI is required but not found"

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

current_version="$(aws "${aws_options[@]}" eks describe-cluster --name "$cluster_name" --query 'cluster.version' --output text 2> /dev/null || true)"
[[ -n "$current_version" && "$current_version" != "None" ]] || die "cluster not found or inaccessible: $cluster_name"

if [[ "$current_version" == "$target_version" ]]; then
  log "cluster already at target version: $target_version"
  exit 0
fi

update_cmd=(aws "${aws_options[@]}" eks update-cluster-version --name "$cluster_name" --kubernetes-version "$target_version")
$force_upgrade && update_cmd+=(--force)

if $dry_run; then
  run_cmd "${update_cmd[@]}"
  exit 0
fi

update_id="$("${update_cmd[@]}" --query 'update.id' --output text)"
[[ -n "$update_id" && "$update_id" != "None" ]] || die "failed to start cluster upgrade"
log "upgrade started: update-id=$update_id"

if $wait_enabled; then
  wait_for_update_success "$update_id"
  wait_for_cluster_active_version
  log "cluster upgrade completed to version $target_version"
fi

printf '%s\n' "$update_id"
exit 0
