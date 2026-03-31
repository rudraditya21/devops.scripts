#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: stop-instance.sh [OPTIONS]

Stop one or more GCP Compute Engine instances.

Options:
  --name NAME             Instance name (repeatable)
  --names CSV             Comma-separated instance names
  --zone ZONE             Instance zone (required)
  --project PROJECT       GCP project override
  --wait                  Wait for TERMINATED state (default)
  --no-wait               Return immediately after API call
  --timeout SEC           Wait timeout in seconds (default: 900)
  --poll-interval SEC     Poll interval in seconds (default: 10)
  --dry-run               Print gcloud commands without executing
  -h, --help              Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [gcp-stop-instance] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

trim_spaces() {
  awk '{$1=$1; print}' <<< "$1"
}

validate_name() {
  [[ "$1" =~ ^[a-z]([-a-z0-9]*[a-z0-9])?$ ]]
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

wait_for_terminated() {
  local start_ts elapsed status name
  start_ts="$(date +%s)"

  while true; do
    pending=0
    for name in "${instance_names[@]}"; do
      status="$(gcloud compute instances describe "$name" --zone "$zone" "${gcloud_opts[@]}" --format 'value(status)' 2> /dev/null || true)"
      if [[ "$status" != "TERMINATED" ]]; then
        pending=$((pending + 1))
      fi
    done

    if ((pending == 0)); then
      return 0
    fi

    elapsed=$(($(date +%s) - start_ts))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for instances to reach TERMINATED"
    fi

    sleep "$poll_interval"
  done
}

instance_names=()
zone=""
project=""
wait_enabled=true
timeout_seconds=900
poll_interval=10
dry_run=false

while (($#)); do
  case "$1" in
    --name)
      shift
      (($#)) || die "--name requires a value"
      validate_name "$1" || die "invalid instance name: $1"
      instance_names+=("$1")
      ;;
    --names)
      shift
      (($#)) || die "--names requires a value"
      IFS=',' read -r -a parsed_names <<< "$1"
      for n in "${parsed_names[@]}"; do
        n="$(trim_spaces "$n")"
        [[ -n "$n" ]] || continue
        validate_name "$n" || die "invalid instance name in --names: $n"
        instance_names+=("$n")
      done
      ;;
    --zone)
      shift
      (($#)) || die "--zone requires a value"
      zone="$1"
      ;;
    --project)
      shift
      (($#)) || die "--project requires a value"
      project="$1"
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
      poll_interval="$1"
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
[[ -n "$zone" ]] || die "--zone is required"
((${#instance_names[@]} > 0)) || die "at least one instance is required (--name/--names)"

gcloud_opts=()
[[ -n "$project" ]] && gcloud_opts+=(--project "$project")

for name in "${instance_names[@]}"; do
  run_cmd gcloud compute instances stop "$name" --zone "$zone" "${gcloud_opts[@]}"
done

log "stop requested for: ${instance_names[*]}"

if $wait_enabled; then
  if $dry_run; then
    log "dry-run mode: skipping wait"
  else
    wait_for_terminated
    log "all instances reached TERMINATED"
  fi
fi
