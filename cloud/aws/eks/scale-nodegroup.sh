#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: scale-nodegroup.sh [OPTIONS]

Scale an EKS managed nodegroup.

Options:
  --cluster-name NAME     Cluster name (required)
  --nodegroup-name NAME   Nodegroup name (required)
  --min-size N            New minimum size
  --max-size N            New maximum size
  --desired-size N        New desired size
  --wait                  Wait for update completion (default)
  --no-wait               Return after update call
  --timeout SEC           Wait timeout (default: 1800)
  --poll-interval SEC     Wait poll interval (default: 20)
  --region REGION         AWS region
  --profile PROFILE       AWS profile
  --dry-run               Print planned commands only
  -h, --help              Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [scale-nodegroup] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

validate_cluster_name() {
  [[ "$1" =~ ^[0-9A-Za-z][A-Za-z0-9_-]{0,99}$ ]]
}

validate_nodegroup_name() {
  [[ "$1" =~ ^[0-9A-Za-z][A-Za-z0-9_-]{0,62}$ ]]
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
    status="$(aws "${aws_options[@]}" eks describe-update --name "$cluster_name" --nodegroup-name "$nodegroup_name" --update-id "$update_id" --query 'update.status' --output text 2> /dev/null || true)"
    case "$status" in
      Successful) return 0 ;;
      Failed | Cancelled) die "nodegroup update failed: $update_id (status=$status)" ;;
    esac

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for nodegroup update: $update_id"
    fi

    sleep "$poll_interval_seconds"
  done
}

cluster_name=""
nodegroup_name=""
min_size=""
max_size=""
desired_size=""
wait_enabled=true
timeout_seconds=1800
poll_interval_seconds=20
region=""
profile=""
dry_run=false

while (($#)); do
  case "$1" in
    --cluster-name)
      shift
      (($#)) || die "--cluster-name requires a value"
      validate_cluster_name "$1" || die "invalid cluster name: $1"
      cluster_name="$1"
      ;;
    --nodegroup-name)
      shift
      (($#)) || die "--nodegroup-name requires a value"
      validate_nodegroup_name "$1" || die "invalid nodegroup name: $1"
      nodegroup_name="$1"
      ;;
    --min-size)
      shift
      (($#)) || die "--min-size requires a value"
      [[ "$1" =~ ^[0-9]+$ ]] || die "--min-size must be non-negative"
      min_size="$1"
      ;;
    --max-size)
      shift
      (($#)) || die "--max-size requires a value"
      [[ "$1" =~ ^[0-9]+$ ]] || die "--max-size must be non-negative"
      max_size="$1"
      ;;
    --desired-size)
      shift
      (($#)) || die "--desired-size requires a value"
      [[ "$1" =~ ^[0-9]+$ ]] || die "--desired-size must be non-negative"
      desired_size="$1"
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

[[ -n "$cluster_name" ]] || die "--cluster-name is required"
[[ -n "$nodegroup_name" ]] || die "--nodegroup-name is required"
if [[ -z "$min_size" && -z "$max_size" && -z "$desired_size" ]]; then
  die "at least one of --min-size, --max-size, or --desired-size is required"
fi
command_exists aws || die "aws CLI is required but not found"

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

read -r current_min current_max current_desired < <(aws "${aws_options[@]}" eks describe-nodegroup \
  --cluster-name "$cluster_name" \
  --nodegroup-name "$nodegroup_name" \
  --query 'nodegroup.scalingConfig.[minSize,maxSize,desiredSize]' \
  --output text 2> /dev/null || true)
[[ -n "$current_min" ]] || die "nodegroup not found or inaccessible"

new_min="${min_size:-$current_min}"
new_max="${max_size:-$current_max}"
new_desired="${desired_size:-$current_desired}"

((new_min <= new_max)) || die "min-size cannot exceed max-size"
((new_desired >= new_min && new_desired <= new_max)) || die "desired-size must be between min and max"

scale_config="minSize=${new_min},maxSize=${new_max},desiredSize=${new_desired}"
update_cmd=(aws "${aws_options[@]}" eks update-nodegroup-config --cluster-name "$cluster_name" --nodegroup-name "$nodegroup_name" --scaling-config "$scale_config")

if $dry_run; then
  run_cmd "${update_cmd[@]}"
  exit 0
fi

update_id="$("${update_cmd[@]}" --query 'update.id' --output text)"
[[ -n "$update_id" && "$update_id" != "None" ]] || die "failed to submit nodegroup scaling update"
log "nodegroup scaling update submitted: $update_id"

if $wait_enabled; then
  wait_for_update_success "$update_id"
  log "nodegroup scaling update completed"
fi

printf '%s\n' "$update_id"
exit 0
