#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: cluster-healthcheck.sh [OPTIONS]

Validate AKS CLI/auth readiness and optional cluster visibility.

Options:
  --name NAME               Optional cluster name
  --resource-group NAME     Resource group for cluster checks
  --subscription ID         Subscription override
  --strict                  Treat WARN as failure
  --json                    Emit JSON report
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

json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

add_check() {
  checks_name+=("$1")
  checks_status+=("$2")
  checks_detail+=("$3")
}

output_text() {
  local i
  printf '%-28s %-8s %s\n' "CHECK" "STATUS" "DETAIL"
  printf '%-28s %-8s %s\n' "-----" "------" "------"
  for i in "${!checks_name[@]}"; do
    printf '%-28s %-8s %s\n' "${checks_name[$i]}" "${checks_status[$i]}" "${checks_detail[$i]}"
  done
  printf '\nSummary: PASS=%s WARN=%s FAIL=%s\n' "$pass_count" "$warn_count" "$fail_count"
}

output_json() {
  local i
  printf '{'
  printf '"summary":{"pass":%s,"warn":%s,"fail":%s},' "$pass_count" "$warn_count" "$fail_count"
  printf '"checks":['
  for i in "${!checks_name[@]}"; do
    ((i > 0)) && printf ','
    printf '{"name":"%s","status":"%s","detail":"%s"}' \
      "$(json_escape "${checks_name[$i]}")" \
      "$(json_escape "${checks_status[$i]}")" \
      "$(json_escape "${checks_detail[$i]}")"
  done
  printf ']}'
  printf '\n'
}

name=""
resource_group=""
subscription=""
strict_mode=false
json_mode=false
checks_name=()
checks_status=()
checks_detail=()

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
    --subscription)
      shift
      (($#)) || die "--subscription requires a value"
      subscription="$1"
      ;;
    --strict)
      strict_mode=true
      ;;
    --json)
      json_mode=true
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

if command_exists az; then
  add_check "cmd:az" "PASS" "az CLI available"
else
  add_check "cmd:az" "FAIL" "az CLI not found"
fi

az_opts=()
[[ -n "$subscription" ]] && az_opts+=(--subscription "$subscription")

if command_exists az; then
  account_name="$(az account show "${az_opts[@]}" --query 'name' --output tsv 2> /dev/null || true)"
  if [[ -n "$account_name" ]]; then
    add_check "auth:account" "PASS" "$account_name"
  else
    add_check "auth:account" "FAIL" "no active Azure account context"
  fi

  if [[ -n "$name" ]]; then
    [[ -n "$resource_group" ]] || die "--resource-group is required when --name is provided"
    cluster_state="$(az aks show --name "$name" --resource-group "$resource_group" "${az_opts[@]}" --query 'provisioningState' --output tsv 2> /dev/null || true)"
    if [[ -n "$cluster_state" ]]; then
      add_check "aks:cluster:$name" "PASS" "state=$cluster_state"
    else
      add_check "aks:cluster:$name" "FAIL" "cluster not found or inaccessible"
    fi
  fi
fi

pass_count=0
warn_count=0
fail_count=0
for status in "${checks_status[@]}"; do
  case "$status" in
    PASS) pass_count=$((pass_count + 1)) ;;
    WARN) warn_count=$((warn_count + 1)) ;;
    FAIL) fail_count=$((fail_count + 1)) ;;
  esac
done

if $json_mode; then
  output_json
else
  output_text
fi

if ((fail_count > 0)); then
  exit 1
fi
if $strict_mode && ((warn_count > 0)); then
  exit 1
fi
