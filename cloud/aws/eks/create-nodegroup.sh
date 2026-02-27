#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: create-nodegroup.sh [OPTIONS]

Create an EKS managed nodegroup.

Options:
  --cluster-name NAME      Cluster name (required)
  --nodegroup-name NAME    Nodegroup name (required)
  --node-role-arn ARN      Node IAM role ARN (required)
  --subnet-ids CSV         Subnet IDs (required)
  --instance-types CSV     Instance types
  --ami-type TYPE          AL2_x86_64|AL2_ARM_64|BOTTLEROCKET_x86_64|BOTTLEROCKET_ARM_64
  --capacity-type TYPE     ON_DEMAND|SPOT (default: ON_DEMAND)
  --disk-size GiB          Root disk size
  --min-size N             Min nodes (default: 1)
  --max-size N             Max nodes (default: 3)
  --desired-size N         Desired nodes (default: 2)
  --labels CSV             Comma-separated key=value labels
  --tag KEY=VALUE          Tag pair (repeatable)
  --tags CSV               Comma-separated tag pairs
  --if-not-exists          Reuse existing nodegroup
  --wait                   Wait for ACTIVE (default)
  --no-wait                Return after create call
  --timeout SEC            Wait timeout (default: 1800)
  --poll-interval SEC      Wait poll interval (default: 20)
  --region REGION          AWS region
  --profile PROFILE        AWS profile
  --dry-run                Print planned commands only
  -h, --help               Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [create-nodegroup] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

trim_spaces() {
  awk '{$1=$1; print}' <<< "$1"
}

validate_cluster_name() {
  [[ "$1" =~ ^[0-9A-Za-z][A-Za-z0-9_-]{0,99}$ ]]
}

validate_nodegroup_name() {
  [[ "$1" =~ ^[0-9A-Za-z][A-Za-z0-9_-]{0,62}$ ]]
}

validate_role_arn() {
  [[ "$1" =~ ^arn:aws[a-zA-Z-]*:iam::[0-9]{12}:role/.+$ ]]
}

validate_subnet_id() {
  [[ "$1" =~ ^subnet-[a-f0-9]{8,17}$ ]]
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

nodegroup_exists() {
  aws "${aws_options[@]}" eks describe-nodegroup --cluster-name "$cluster_name" --nodegroup-name "$nodegroup_name" > /dev/null 2>&1
}

wait_for_nodegroup_active() {
  local start_time elapsed status
  start_time="$(date +%s)"

  while true; do
    status="$(aws "${aws_options[@]}" eks describe-nodegroup --cluster-name "$cluster_name" --nodegroup-name "$nodegroup_name" --query 'nodegroup.status' --output text 2> /dev/null || true)"
    case "$status" in
      ACTIVE) return 0 ;;
      CREATE_FAILED) die "nodegroup creation failed: $nodegroup_name" ;;
    esac

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for nodegroup ACTIVE: $nodegroup_name"
    fi

    sleep "$poll_interval_seconds"
  done
}

cluster_name=""
nodegroup_name=""
node_role_arn=""
subnet_ids=()
instance_types=()
ami_type=""
capacity_type="ON_DEMAND"
disk_size=""
min_size=1
max_size=3
desired_size=2
label_pairs=()
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
    --node-role-arn)
      shift
      (($#)) || die "--node-role-arn requires a value"
      validate_role_arn "$1" || die "invalid node role ARN: $1"
      node_role_arn="$1"
      ;;
    --subnet-ids)
      shift
      (($#)) || die "--subnet-ids requires a value"
      IFS=',' read -r -a parsed_subnets <<< "$1"
      for s in "${parsed_subnets[@]}"; do
        s="$(trim_spaces "$s")"
        [[ -n "$s" ]] || continue
        validate_subnet_id "$s" || die "invalid subnet ID: $s"
        subnet_ids+=("$s")
      done
      ;;
    --instance-types)
      shift
      (($#)) || die "--instance-types requires a value"
      IFS=',' read -r -a parsed_types <<< "$1"
      for it in "${parsed_types[@]}"; do
        it="$(trim_spaces "$it")"
        [[ -n "$it" ]] || continue
        instance_types+=("$it")
      done
      ;;
    --ami-type)
      shift
      (($#)) || die "--ami-type requires a value"
      ami_type="$1"
      ;;
    --capacity-type)
      shift
      (($#)) || die "--capacity-type requires a value"
      case "$1" in
        ON_DEMAND | SPOT) capacity_type="$1" ;;
        *) die "invalid capacity type: $1" ;;
      esac
      ;;
    --disk-size)
      shift
      (($#)) || die "--disk-size requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--disk-size must be a positive integer"
      disk_size="$1"
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
    --labels)
      shift
      (($#)) || die "--labels requires a value"
      IFS=',' read -r -a parsed_labels <<< "$1"
      for pair in "${parsed_labels[@]}"; do
        pair="$(trim_spaces "$pair")"
        [[ -n "$pair" ]] || continue
        validate_tag_pair "$pair" || die "invalid label key=value: $pair"
        label_pairs+=("$pair")
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

[[ -n "$cluster_name" ]] || die "--cluster-name is required"
[[ -n "$nodegroup_name" ]] || die "--nodegroup-name is required"
[[ -n "$node_role_arn" ]] || die "--node-role-arn is required"
((${#subnet_ids[@]} > 0)) || die "at least one subnet ID is required"
((min_size <= max_size)) || die "--min-size cannot exceed --max-size"
((desired_size >= min_size && desired_size <= max_size)) || die "--desired-size must be between min and max"
command_exists aws || die "aws CLI is required but not found"

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

aws "${aws_options[@]}" eks describe-cluster --name "$cluster_name" > /dev/null 2>&1 || die "cluster not found or inaccessible: $cluster_name"

if nodegroup_exists; then
  if $if_not_exists; then
    log "nodegroup already exists: $nodegroup_name"
    printf '%s\n' "$nodegroup_name"
    exit 0
  fi
  die "nodegroup already exists: $nodegroup_name"
fi

create_cmd=(aws "${aws_options[@]}" eks create-nodegroup
  --cluster-name "$cluster_name"
  --nodegroup-name "$nodegroup_name"
  --node-role "$node_role_arn"
  --subnets "${subnet_ids[@]}"
  --scaling-config "minSize=${min_size},maxSize=${max_size},desiredSize=${desired_size}"
  --capacity-type "$capacity_type")

((${#instance_types[@]} > 0)) && create_cmd+=(--instance-types "${instance_types[@]}")
[[ -n "$ami_type" ]] && create_cmd+=(--ami-type "$ami_type")
[[ -n "$disk_size" ]] && create_cmd+=(--disk-size "$disk_size")

if ((${#label_pairs[@]} > 0)); then
  labels_map=""
  for pair in "${label_pairs[@]}"; do
    parse_tag_pair "$pair"
    [[ -n "$labels_map" ]] && labels_map+=","
    labels_map+="${tag_key}=${tag_value}"
  done
  create_cmd+=(--labels "$labels_map")
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
log "nodegroup create requested: $nodegroup_name"

if $wait_enabled && ! $dry_run; then
  wait_for_nodegroup_active
  log "nodegroup is ACTIVE: $nodegroup_name"
fi

printf '%s\n' "$nodegroup_name"
exit 0
