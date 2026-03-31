#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: stop-vm.sh [OPTIONS]

Stop one or more Azure VMs in a resource group.

Options:
  --resource-group NAME   Resource group containing VMs (required)
  --name NAME             VM name (repeatable)
  --names CSV             Comma-separated VM names
  --subscription ID       Azure subscription override
  --deallocate            Deallocate VM after stop (default)
  --no-deallocate         Stop VM without deallocation
  --wait                  Wait for final power state (default)
  --no-wait               Return immediately after stop calls
  --timeout SEC           Wait timeout in seconds (default: 900)
  --poll-interval SEC     Poll interval in seconds (default: 10)
  --dry-run               Print az commands without executing
  -h, --help              Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [azure-stop-vm] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

trim_spaces() {
  awk '{$1=$1; print}' <<< "$1"
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

wait_for_stopped() {
  local start_ts elapsed vm_name state expected
  start_ts="$(date +%s)"
  expected="VM stopped"
  $deallocate && expected="VM deallocated"

  while true; do
    pending=0
    for vm_name in "${vm_names[@]}"; do
      state="$(az vm get-instance-view --resource-group "$resource_group" --name "$vm_name" "${az_opts[@]}" --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus | [0]" --output tsv 2> /dev/null || true)"
      if [[ "$state" != "$expected" ]]; then
        pending=$((pending + 1))
      fi
    done

    if ((pending == 0)); then
      return 0
    fi

    elapsed=$(($(date +%s) - start_ts))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for VMs to reach expected stopped state"
    fi

    sleep "$poll_interval"
  done
}

resource_group=""
subscription=""
vm_names=()
deallocate=true
wait_enabled=true
timeout_seconds=900
poll_interval=10
dry_run=false

while (($#)); do
  case "$1" in
    --resource-group)
      shift
      (($#)) || die "--resource-group requires a value"
      resource_group="$1"
      ;;
    --name)
      shift
      (($#)) || die "--name requires a value"
      vm_names+=("$1")
      ;;
    --names)
      shift
      (($#)) || die "--names requires a value"
      IFS=',' read -r -a parsed_names <<< "$1"
      for n in "${parsed_names[@]}"; do
        n="$(trim_spaces "$n")"
        [[ -n "$n" ]] || continue
        vm_names+=("$n")
      done
      ;;
    --subscription)
      shift
      (($#)) || die "--subscription requires a value"
      subscription="$1"
      ;;
    --deallocate)
      deallocate=true
      ;;
    --no-deallocate)
      deallocate=false
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

command_exists az || die "az CLI is required but not found"
[[ -n "$resource_group" ]] || die "--resource-group is required"
((${#vm_names[@]} > 0)) || die "at least one VM name is required"

az_opts=()
[[ -n "$subscription" ]] && az_opts+=(--subscription "$subscription")

for vm_name in "${vm_names[@]}"; do
  if $deallocate; then
    run_cmd az vm deallocate --resource-group "$resource_group" --name "$vm_name" "${az_opts[@]}"
  else
    run_cmd az vm stop --resource-group "$resource_group" --name "$vm_name" "${az_opts[@]}"
  fi
done

log "stop requested for: ${vm_names[*]}"

if $wait_enabled; then
  if $dry_run; then
    log "dry-run mode: skipping wait"
  else
    wait_for_stopped
    log "all VMs reached expected stopped state"
  fi
fi
