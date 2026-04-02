#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: rightsizing.sh [OPTIONS]

Evaluate gcp utilization and suggest rightsizing action.

Options:
  --cpu-util PERCENT       Current average CPU utilization (required)
  --memory-util PERCENT    Current average memory utilization (required)
  --cpu-target PERCENT     Target CPU utilization (default: 55)
  --memory-target PERCENT  Target memory utilization (default: 65)
  --json                   Emit JSON output
  -h, --help               Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

is_number() {
  [[ "$1" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]
}

cpu_util=""
mem_util=""
cpu_target="55"
mem_target="65"
json=false

while (($#)); do
  case "$1" in
    --cpu-util) shift; (($#)) || die "--cpu-util requires a value"; cpu_util="$1" ;;
    --memory-util) shift; (($#)) || die "--memory-util requires a value"; mem_util="$1" ;;
    --cpu-target) shift; (($#)) || die "--cpu-target requires a value"; cpu_target="$1" ;;
    --memory-target) shift; (($#)) || die "--memory-target requires a value"; mem_target="$1" ;;
    --json) json=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$cpu_util" ]] || die "--cpu-util is required"
[[ -n "$mem_util" ]] || die "--memory-util is required"
for v in "$cpu_util" "$mem_util" "$cpu_target" "$mem_target"; do
  is_number "$v" || die "all utilization/target values must be numeric"
done

action="KEEP"
rationale="utilization within target range"

if awk -v c="$cpu_util" -v m="$mem_util" -v ct="$cpu_target" -v mt="$mem_target" 'BEGIN { exit !((c < (ct * 0.60)) && (m < (mt * 0.60))) }'; then
  action="DOWNSIZE"
  rationale="both cpu and memory are significantly below targets"
elif awk -v c="$cpu_util" -v m="$mem_util" -v ct="$cpu_target" -v mt="$mem_target" 'BEGIN { exit !((c > (ct * 1.30)) || (m > (mt * 1.30))) }'; then
  action="UPSIZE"
  rationale="cpu or memory utilization is significantly above targets"
fi

if $json; then
  printf '{"provider":"gcp","cpu_util":%s,"memory_util":%s,"cpu_target":%s,"memory_target":%s,"action":"%s","rationale":"%s"}\n' \
    "$cpu_util" "$mem_util" "$cpu_target" "$mem_target" "$action" "$rationale"
else
  printf 'provider: gcp\n'
  printf 'cpu_util: %s\n' "$cpu_util"
  printf 'memory_util: %s\n' "$mem_util"
  printf 'cpu_target: %s\n' "$cpu_target"
  printf 'memory_target: %s\n' "$mem_target"
  printf 'action: %s\n' "$action"
  printf 'rationale: %s\n' "$rationale"
fi

exit 0
