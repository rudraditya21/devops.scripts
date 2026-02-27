#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: create-cluster.sh [OPTIONS]

Create an EKS cluster with VPC/network settings and optional logging/tags.

Options:
  --name NAME                 Cluster name (required)
  --role-arn ARN              EKS service role ARN (required)
  --subnet-ids CSV            Subnet IDs (required, at least 2)
  --security-group-ids CSV    Security group IDs
  --version VERSION           Kubernetes version
  --endpoint-public-access B  true|false (default: true)
  --endpoint-private-access B true|false (default: false)
  --public-access-cidrs CSV   CIDR allow list for public endpoint
  --logging-types CSV         api,audit,authenticator,controllerManager,scheduler
  --tag KEY=VALUE             Tag pair (repeatable)
  --tags CSV                  Comma-separated tag pairs
  --if-not-exists             Reuse existing cluster
  --wait                      Wait for ACTIVE (default)
  --no-wait                   Return after API request
  --timeout SEC               Wait timeout (default: 1800)
  --poll-interval SEC         Wait poll interval (default: 20)
  --region REGION             AWS region
  --profile PROFILE           AWS profile
  --dry-run                   Print planned commands only
  -h, --help                  Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [create-cluster] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

trim_spaces() {
  awk '{$1=$1; print}' <<< "$1"
}

normalize_bool() {
  case "$1" in
    true | 1 | yes | on) printf 'true' ;;
    false | 0 | no | off) printf 'false' ;;
    *) die "invalid boolean value: $1 (use true/false)" ;;
  esac
}

validate_cluster_name() {
  [[ "$1" =~ ^[0-9A-Za-z][A-Za-z0-9_-]{0,99}$ ]]
}

validate_role_arn() {
  [[ "$1" =~ ^arn:aws[a-zA-Z-]*:iam::[0-9]{12}:role/.+$ ]]
}

validate_subnet_id() {
  [[ "$1" =~ ^subnet-[a-f0-9]{8,17}$ ]]
}

validate_sg_id() {
  [[ "$1" =~ ^sg-[a-f0-9]{8,17}$ ]]
}

validate_cidr() {
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]
}

validate_tag_pair() {
  [[ "$1" =~ ^[^=]+=[^=].*$ ]]
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

parse_tag_pair() {
  local pair="$1"
  tag_key="${pair%%=*}"
  tag_value="${pair#*=}"
}

cluster_exists() {
  aws "${aws_options[@]}" eks describe-cluster --name "$cluster_name" > /dev/null 2>&1
}

wait_for_cluster_active() {
  local start_time elapsed status
  start_time="$(date +%s)"

  while true; do
    status="$(aws "${aws_options[@]}" eks describe-cluster --name "$cluster_name" --query 'cluster.status' --output text 2> /dev/null || true)"
    case "$status" in
      ACTIVE) return 0 ;;
      FAILED) die "cluster entered FAILED state: $cluster_name" ;;
    esac

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for cluster ACTIVE: $cluster_name"
    fi

    sleep "$poll_interval_seconds"
  done
}

cluster_name=""
role_arn=""
subnet_ids=()
security_group_ids=()
cluster_version=""
endpoint_public_access=true
endpoint_private_access=false
public_access_cidrs=()
logging_types=()
tag_pairs=()
if_not_exists=false
wait_enabled=true
timeout_seconds=1800
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
    --role-arn)
      shift
      (($#)) || die "--role-arn requires a value"
      validate_role_arn "$1" || die "invalid role ARN: $1"
      role_arn="$1"
      ;;
    --subnet-ids)
      shift
      (($#)) || die "--subnet-ids requires a value"
      IFS=',' read -r -a parsed_subnets <<< "$1"
      for item in "${parsed_subnets[@]}"; do
        item="$(trim_spaces "$item")"
        [[ -n "$item" ]] || continue
        validate_subnet_id "$item" || die "invalid subnet ID: $item"
        subnet_ids+=("$item")
      done
      ;;
    --security-group-ids)
      shift
      (($#)) || die "--security-group-ids requires a value"
      IFS=',' read -r -a parsed_sgs <<< "$1"
      for item in "${parsed_sgs[@]}"; do
        item="$(trim_spaces "$item")"
        [[ -n "$item" ]] || continue
        validate_sg_id "$item" || die "invalid security group ID: $item"
        security_group_ids+=("$item")
      done
      ;;
    --version)
      shift
      (($#)) || die "--version requires a value"
      cluster_version="$1"
      ;;
    --endpoint-public-access)
      shift
      (($#)) || die "--endpoint-public-access requires a value"
      endpoint_public_access="$(normalize_bool "$1")"
      ;;
    --endpoint-private-access)
      shift
      (($#)) || die "--endpoint-private-access requires a value"
      endpoint_private_access="$(normalize_bool "$1")"
      ;;
    --public-access-cidrs)
      shift
      (($#)) || die "--public-access-cidrs requires a value"
      IFS=',' read -r -a parsed_cidrs <<< "$1"
      for item in "${parsed_cidrs[@]}"; do
        item="$(trim_spaces "$item")"
        [[ -n "$item" ]] || continue
        validate_cidr "$item" || die "invalid CIDR: $item"
        public_access_cidrs+=("$item")
      done
      ;;
    --logging-types)
      shift
      (($#)) || die "--logging-types requires a value"
      IFS=',' read -r -a parsed_types <<< "$1"
      for item in "${parsed_types[@]}"; do
        item="$(trim_spaces "$item")"
        [[ -n "$item" ]] || continue
        case "$item" in
          api | audit | authenticator | controllerManager | scheduler) ;;
          *) die "invalid logging type: $item" ;;
        esac
        logging_types+=("$item")
      done
      ;;
    --tag)
      shift
      (($#)) || die "--tag requires a value"
      validate_tag_pair "$1" || die "invalid --tag format: $1"
      tag_pairs+=("$1")
      ;;
    --tags)
      shift
      (($#)) || die "--tags requires a value"
      IFS=',' read -r -a parsed_tags <<< "$1"
      for pair in "${parsed_tags[@]}"; do
        pair="$(trim_spaces "$pair")"
        [[ -n "$pair" ]] || continue
        validate_tag_pair "$pair" || die "invalid tag in --tags: $pair"
        tag_pairs+=("$pair")
      done
      ;;
    --if-not-exists)
      if_not_exists=true
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
[[ -n "$role_arn" ]] || die "--role-arn is required"
((${#subnet_ids[@]} >= 2)) || die "at least 2 subnet IDs are required"
command_exists aws || die "aws CLI is required but not found"

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

if cluster_exists; then
  if $if_not_exists; then
    log "cluster already exists: $cluster_name"
    printf '%s\n' "$cluster_name"
    exit 0
  fi
  die "cluster already exists: $cluster_name"
fi

vpc_config="subnetIds=$(
  IFS=','
  printf '%s' "${subnet_ids[*]}"
)"
if ((${#security_group_ids[@]} > 0)); then
  vpc_config+=",securityGroupIds=$(
    IFS=','
    printf '%s' "${security_group_ids[*]}"
  )"
fi
vpc_config+=",endpointPublicAccess=${endpoint_public_access},endpointPrivateAccess=${endpoint_private_access}"
if ((${#public_access_cidrs[@]} > 0)); then
  vpc_config+=",publicAccessCidrs=$(
    IFS=','
    printf '%s' "${public_access_cidrs[*]}"
  )"
fi

create_cmd=(aws "${aws_options[@]}" eks create-cluster --name "$cluster_name" --role-arn "$role_arn" --resources-vpc-config "$vpc_config")
[[ -n "$cluster_version" ]] && create_cmd+=(--version "$cluster_version")

if ((${#logging_types[@]} > 0)); then
  logging_value="clusterLogging=[{types=[$(
    IFS=','
    printf '%s' "${logging_types[*]}"
  )],enabled=true}]"
  create_cmd+=(--logging "$logging_value")
fi

if ((${#tag_pairs[@]} > 0)); then
  tags_map=""
  for pair in "${tag_pairs[@]}"; do
    parse_tag_pair "$pair"
    [[ -n "$tags_map" ]] && tags_map+=","
    tags_map+="${tag_key}=${tag_value}"
  done
  create_cmd+=(--tags "$tags_map")
fi

run_cmd "${create_cmd[@]}" > /dev/null
log "cluster create requested: $cluster_name"

if $wait_enabled && ! $dry_run; then
  wait_for_cluster_active
  log "cluster is ACTIVE: $cluster_name"
fi

printf '%s\n' "$cluster_name"
exit 0
