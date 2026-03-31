#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: cluster-healthcheck.sh [OPTIONS]

Validate GKE CLI/auth readiness and optional cluster visibility.

Options:
  --name NAME           Optional cluster name to verify
  --zone ZONE           Cluster zone
  --region REGION       Cluster region
  --project PROJECT     GCP project override
  --strict              Treat WARN as failure
  --json                Emit JSON report
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

cluster_name=""
zone=""
region=""
project=""
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

if [[ -n "$zone" && -n "$region" ]]; then
  die "use either --zone or --region, not both"
fi

if command_exists gcloud; then
  add_check "cmd:gcloud" "PASS" "gcloud available"
else
  add_check "cmd:gcloud" "FAIL" "gcloud not found"
fi

if command_exists gcloud; then
  active_account="$(gcloud auth list --filter=status:ACTIVE --format 'value(account)' 2> /dev/null || true)"
  if [[ -n "$active_account" ]]; then
    add_check "auth:active-account" "PASS" "$active_account"
  else
    add_check "auth:active-account" "FAIL" "no active gcloud account"
  fi

  effective_project="$project"
  if [[ -z "$effective_project" ]]; then
    effective_project="$(gcloud config get-value project 2> /dev/null || true)"
  fi

  if [[ -n "$effective_project" ]]; then
    add_check "config:project" "PASS" "$effective_project"
  else
    add_check "config:project" "WARN" "no default project configured"
  fi

  if [[ -n "$cluster_name" ]]; then
    describe_cmd=(gcloud container clusters describe "$cluster_name")
    [[ -n "$zone" ]] && describe_cmd+=(--zone "$zone")
    [[ -n "$region" ]] && describe_cmd+=(--region "$region")
    [[ -n "$effective_project" ]] && describe_cmd+=(--project "$effective_project")

    cluster_status="$("${describe_cmd[@]}" --format 'value(status)' 2> /dev/null || true)"
    if [[ -n "$cluster_status" ]]; then
      add_check "gke:cluster:$cluster_name" "PASS" "status=$cluster_status"
    else
      add_check "gke:cluster:$cluster_name" "FAIL" "cluster not found or inaccessible"
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
