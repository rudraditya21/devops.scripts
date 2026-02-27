#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: cluster-healthcheck.sh [OPTIONS]

Run EKS cluster health and readiness checks.

Options:
  --cluster-name NAME      Cluster name (required)
  --require-nodegroups     Fail if cluster has zero nodegroups
  --kubectl-check          Include kubectl connectivity/node checks
  --kubeconfig PATH        Kubeconfig file path for kubectl checks
  --max-unready-nodes N    Allowed unready nodes for kubectl check (default: 0)
  --region REGION          AWS region
  --profile PROFILE        AWS profile
  --strict                 Fail on WARN
  --json                   Emit JSON report
  -h, --help               Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
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

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

validate_cluster_name() {
  [[ "$1" =~ ^[0-9A-Za-z][A-Za-z0-9_-]{0,99}$ ]]
}

add_check() {
  checks_name+=("$1")
  checks_status+=("$2")
  checks_detail+=("$3")
}

output_text() {
  local i
  printf '%-32s %-8s %s\n' "CHECK" "STATUS" "DETAIL"
  printf '%-32s %-8s %s\n' "-----" "------" "------"
  for i in "${!checks_name[@]}"; do
    printf '%-32s %-8s %s\n' "${checks_name[$i]}" "${checks_status[$i]}" "${checks_detail[$i]}"
  done
  printf '\nSummary: PASS=%s WARN=%s FAIL=%s\n' "$pass_count" "$warn_count" "$fail_count"
}

output_json() {
  local i
  printf '{'
  printf '"summary":{'
  printf '"pass":%s,' "$pass_count"
  printf '"warn":%s,' "$warn_count"
  printf '"fail":%s' "$fail_count"
  printf '},'
  printf '"checks":['
  for i in "${!checks_name[@]}"; do
    ((i > 0)) && printf ','
    printf '{'
    printf '"name":"%s",' "$(json_escape "${checks_name[$i]}")"
    printf '"status":"%s",' "$(json_escape "${checks_status[$i]}")"
    printf '"detail":"%s"' "$(json_escape "${checks_detail[$i]}")"
    printf '}'
  done
  printf ']'
  printf '}\n'
}

cluster_name=""
require_nodegroups=false
kubectl_check=false
kubeconfig_path=""
max_unready_nodes=0
region=""
profile=""
strict_mode=false
json_mode=false
checks_name=()
checks_status=()
checks_detail=()

while (($#)); do
  case "$1" in
    --cluster-name)
      shift
      (($#)) || die "--cluster-name requires a value"
      validate_cluster_name "$1" || die "invalid cluster name: $1"
      cluster_name="$1"
      ;;
    --require-nodegroups)
      require_nodegroups=true
      ;;
    --kubectl-check)
      kubectl_check=true
      ;;
    --kubeconfig)
      shift
      (($#)) || die "--kubeconfig requires a value"
      kubeconfig_path="$1"
      ;;
    --max-unready-nodes)
      shift
      (($#)) || die "--max-unready-nodes requires a value"
      [[ "$1" =~ ^[0-9]+$ ]] || die "--max-unready-nodes must be a non-negative integer"
      max_unready_nodes="$1"
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

[[ -n "$cluster_name" ]] || die "--cluster-name is required"

if command_exists aws; then
  add_check "cmd:aws" "PASS" "aws CLI found"
else
  add_check "cmd:aws" "FAIL" "aws CLI not found"
fi

aws_opts=()
[[ -n "$region" ]] && aws_opts+=(--region "$region")
[[ -n "$profile" ]] && aws_opts+=(--profile "$profile")

if command_exists aws; then
  cluster_status="$(aws "${aws_opts[@]}" eks describe-cluster --name "$cluster_name" --query 'cluster.status' --output text 2> /dev/null || true)"
  if [[ -z "$cluster_status" || "$cluster_status" == "None" ]]; then
    add_check "cluster:exists" "FAIL" "cluster not found or inaccessible: $cluster_name"
  else
    add_check "cluster:exists" "PASS" "$cluster_name"

    if [[ "$cluster_status" == "ACTIVE" ]]; then
      add_check "cluster:status" "PASS" "$cluster_status"
    else
      add_check "cluster:status" "WARN" "$cluster_status"
    fi

    cluster_version="$(aws "${aws_opts[@]}" eks describe-cluster --name "$cluster_name" --query 'cluster.version' --output text 2> /dev/null || true)"
    [[ -n "$cluster_version" && "$cluster_version" != "None" ]] && add_check "cluster:version" "PASS" "$cluster_version"

    endpoint_public="$(aws "${aws_opts[@]}" eks describe-cluster --name "$cluster_name" --query 'cluster.resourcesVpcConfig.endpointPublicAccess' --output text 2> /dev/null || true)"
    endpoint_private="$(aws "${aws_opts[@]}" eks describe-cluster --name "$cluster_name" --query 'cluster.resourcesVpcConfig.endpointPrivateAccess' --output text 2> /dev/null || true)"
    add_check "cluster:endpoint-access" "PASS" "public=$endpoint_public private=$endpoint_private"

    oidc_issuer="$(aws "${aws_opts[@]}" eks describe-cluster --name "$cluster_name" --query 'cluster.identity.oidc.issuer' --output text 2> /dev/null || true)"
    if [[ -n "$oidc_issuer" && "$oidc_issuer" != "None" ]]; then
      add_check "cluster:oidc" "PASS" "$oidc_issuer"
    else
      add_check "cluster:oidc" "WARN" "OIDC issuer not configured"
    fi

    nodegroups=()
    while read -r ng; do
      [[ -n "$ng" ]] || continue
      nodegroups+=("$ng")
    done < <(aws "${aws_opts[@]}" eks list-nodegroups --cluster-name "$cluster_name" --query 'nodegroups' --output text 2> /dev/null | tr '\t' '\n')

    ng_count=${#nodegroups[@]}
    if ((ng_count == 0)); then
      if $require_nodegroups; then
        add_check "nodegroups:count" "FAIL" "0"
      else
        add_check "nodegroups:count" "WARN" "0"
      fi
    else
      add_check "nodegroups:count" "PASS" "$ng_count"
    fi

    bad_nodegroups=0
    for ng in "${nodegroups[@]}"; do
      ng_status="$(aws "${aws_opts[@]}" eks describe-nodegroup --cluster-name "$cluster_name" --nodegroup-name "$ng" --query 'nodegroup.status' --output text 2> /dev/null || true)"
      if [[ "$ng_status" != "ACTIVE" ]]; then
        bad_nodegroups=$((bad_nodegroups + 1))
      fi
    done

    if ((bad_nodegroups == 0)); then
      add_check "nodegroups:status" "PASS" "all ACTIVE"
    else
      add_check "nodegroups:status" "WARN" "$bad_nodegroups non-ACTIVE"
    fi
  fi
fi

if $kubectl_check; then
  if ! command_exists kubectl; then
    add_check "cmd:kubectl" "FAIL" "kubectl not found"
  else
    add_check "cmd:kubectl" "PASS" "kubectl found"

    kubectl_base=(kubectl)
    [[ -n "$kubeconfig_path" ]] && kubectl_base+=(--kubeconfig "$kubeconfig_path")

    if "${kubectl_base[@]}" cluster-info > /dev/null 2>&1; then
      add_check "kubectl:cluster-info" "PASS" "reachable"

      nodes_output="$("${kubectl_base[@]}" get nodes --no-headers 2> /dev/null || true)"
      if [[ -z "$nodes_output" ]]; then
        add_check "kubectl:nodes" "WARN" "no nodes returned"
      else
        total_nodes=$(awk 'NF>0{c++} END{print c+0}' <<< "$nodes_output")
        unready_nodes=$(awk 'NF>1 { if ($2 !~ /^Ready/) c++ } END { print c+0 }' <<< "$nodes_output")

        if ((unready_nodes <= max_unready_nodes)); then
          add_check "kubectl:node-readiness" "PASS" "total=$total_nodes unready=$unready_nodes"
        else
          add_check "kubectl:node-readiness" "FAIL" "total=$total_nodes unready=$unready_nodes max=$max_unready_nodes"
        fi
      fi
    else
      add_check "kubectl:cluster-info" "FAIL" "unable to reach cluster via kubeconfig/context"
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

exit 0
