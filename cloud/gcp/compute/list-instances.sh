#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: list-instances.sh [OPTIONS]

List GCP Compute Engine instances with filtering and output control.

Options:
  --project PROJECT       GCP project override
  --zone ZONE             Zone filter (repeatable)
  --state STATE           Instance state filter (repeatable)
  --name NAME             Instance name filter (repeatable)
  --output MODE           table|json|names (default: table)
  --dry-run               Print gcloud command without executing
  -h, --help              Show help
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

project=""
zones=()
states=()
names=()
output_mode="table"
dry_run=false

while (($#)); do
  case "$1" in
    --project)
      shift
      (($#)) || die "--project requires a value"
      project="$1"
      ;;
    --zone)
      shift
      (($#)) || die "--zone requires a value"
      zones+=("$1")
      ;;
    --state)
      shift
      (($#)) || die "--state requires a value"
      states+=("$1")
      ;;
    --name)
      shift
      (($#)) || die "--name requires a value"
      names+=("$1")
      ;;
    --output)
      shift
      (($#)) || die "--output requires a value"
      case "$1" in
        table | json | names) output_mode="$1" ;;
        *) die "invalid --output value: $1" ;;
      esac
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

cmd=(gcloud compute instances list)
[[ -n "$project" ]] && cmd+=(--project "$project")

for zone in "${zones[@]}"; do
  cmd+=(--zones "$zone")
done

filters=()
for state in "${states[@]}"; do
  filters+=("status=${state}")
done
for name in "${names[@]}"; do
  filters+=("name=${name}")
done

if ((${#filters[@]} > 0)); then
  filter_expr=""
  for f in "${filters[@]}"; do
    if [[ -n "$filter_expr" ]]; then
      filter_expr+=" AND "
    fi
    filter_expr+="$f"
  done
  cmd+=(--filter "$filter_expr")
fi

case "$output_mode" in
  table)
    cmd+=(--format 'table(name,zone.basename(),machineType.basename(),status,networkInterfaces[0].networkIP,networkInterfaces[0].accessConfigs[0].natIP)')
    ;;
  json)
    cmd+=(--format json)
    ;;
  names)
    cmd+=(--format 'value(name)')
    ;;
esac

run_cmd "${cmd[@]}"
