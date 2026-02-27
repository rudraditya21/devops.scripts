#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: kubeconfig-update.sh [OPTIONS]

Update local kubeconfig for an EKS cluster.

Options:
  --cluster-name NAME    Cluster name (required)
  --alias NAME           Context alias
  --kubeconfig PATH      Kubeconfig file path
  --role-arn ARN         Role ARN to assume for cluster auth
  --region REGION        AWS region
  --profile PROFILE      AWS profile
  --validate             Run kubectl validation after update
  --dry-run              Print planned commands only
  -h, --help             Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [kubeconfig-update] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

validate_cluster_name() {
  [[ "$1" =~ ^[0-9A-Za-z][A-Za-z0-9_-]{0,99}$ ]]
}

validate_role_arn() {
  [[ "$1" =~ ^arn:aws[a-zA-Z-]*:iam::[0-9]{12}:role/.+$ ]]
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

cluster_name=""
context_alias=""
kubeconfig_path=""
role_arn=""
region=""
profile=""
validate=false
dry_run=false

while (($#)); do
  case "$1" in
    --cluster-name)
      shift
      (($#)) || die "--cluster-name requires a value"
      validate_cluster_name "$1" || die "invalid cluster name: $1"
      cluster_name="$1"
      ;;
    --alias)
      shift
      (($#)) || die "--alias requires a value"
      context_alias="$1"
      ;;
    --kubeconfig)
      shift
      (($#)) || die "--kubeconfig requires a value"
      kubeconfig_path="$1"
      ;;
    --role-arn)
      shift
      (($#)) || die "--role-arn requires a value"
      validate_role_arn "$1" || die "invalid role ARN: $1"
      role_arn="$1"
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
    --validate)
      validate=true
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
command_exists aws || die "aws CLI is required but not found"

aws_opts=()
[[ -n "$region" ]] && aws_opts+=(--region "$region")
[[ -n "$profile" ]] && aws_opts+=(--profile "$profile")

aws "${aws_opts[@]}" eks describe-cluster --name "$cluster_name" > /dev/null 2>&1 || die "cluster not found or inaccessible: $cluster_name"

cmd=(aws "${aws_opts[@]}" eks update-kubeconfig --name "$cluster_name")
[[ -n "$context_alias" ]] && cmd+=(--alias "$context_alias")
[[ -n "$kubeconfig_path" ]] && cmd+=(--kubeconfig "$kubeconfig_path")
[[ -n "$role_arn" ]] && cmd+=(--role-arn "$role_arn")

run_cmd "${cmd[@]}"
log "kubeconfig updated for cluster: $cluster_name"

if $validate; then
  command_exists kubectl || die "kubectl is required for --validate"

  kubectl_cmd=(kubectl cluster-info)
  [[ -n "$kubeconfig_path" ]] && kubectl_cmd+=(--kubeconfig "$kubeconfig_path")

  if $dry_run; then
    run_cmd "${kubectl_cmd[@]}"
  else
    "${kubectl_cmd[@]}" > /dev/null
    log "kubectl validation succeeded"
  fi
fi

exit 0
