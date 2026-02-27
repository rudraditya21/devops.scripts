#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: create-ami.sh [OPTIONS]

Create an AMI from an EC2 instance with optional tags and wait.

Options:
  --id INSTANCE_ID      Source instance ID (required)
  --name NAME           AMI name (required)
  --description TEXT    AMI description
  --tag KEY=VALUE       AMI tag pair (repeatable)
  --tags CSV            Comma-separated AMI tag pairs
  --no-reboot           Avoid rebooting the instance during image creation
  --wait                Wait until AMI becomes available
  --timeout SEC         Wait timeout in seconds (default: 3600)
  --poll-interval SEC   Poll interval in seconds (default: 20)
  --region REGION       AWS region
  --profile PROFILE     AWS CLI profile
  --dry-run             Print actions without executing
  -h, --help            Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [create-ami] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

trim_spaces() {
  awk '{$1=$1; print}' <<< "$1"
}

validate_instance_id() {
  [[ "$1" =~ ^i-[a-f0-9]{8,17}$ ]]
}

validate_ami_name() {
  [[ "$1" =~ ^[A-Za-z0-9()_.:/-]{3,128}$ ]]
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

wait_for_ami_available() {
  local image_id="$1"
  local start_time elapsed state
  start_time="$(date +%s)"

  while true; do
    state="$(aws "${aws_options[@]}" ec2 describe-images \
      --image-ids "$image_id" \
      --query 'Images[0].State' \
      --output text)"

    case "$state" in
      available) return 0 ;;
      failed) die "AMI creation failed for $image_id" ;;
    esac

    elapsed=$(($(date +%s) - start_time))
    if ((elapsed >= timeout_seconds)); then
      die "timeout waiting for AMI $image_id to become available"
    fi

    sleep "$poll_interval"
  done
}

aws_options=()
instance_id=""
ami_name=""
description=""
tag_pairs=()
no_reboot=false
wait_enabled=false
timeout_seconds=3600
poll_interval=20
dry_run=false

while (($#)); do
  case "$1" in
    --id)
      shift
      (($#)) || die "--id requires a value"
      validate_instance_id "$1" || die "invalid instance ID: $1"
      instance_id="$1"
      ;;
    --name)
      shift
      (($#)) || die "--name requires a value"
      validate_ami_name "$1" || die "invalid AMI name format"
      ami_name="$1"
      ;;
    --description)
      shift
      (($#)) || die "--description requires a value"
      description="$1"
      ;;
    --tag)
      shift
      (($#)) || die "--tag requires a value"
      validate_tag_pair "$1" || die "invalid --tag format (expected KEY=VALUE): $1"
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
    --no-reboot)
      no_reboot=true
      ;;
    --wait)
      wait_enabled=true
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
    --region)
      shift
      (($#)) || die "--region requires a value"
      aws_options+=(--region "$1")
      ;;
    --profile)
      shift
      (($#)) || die "--profile requires a value"
      aws_options+=(--profile "$1")
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

command_exists aws || die "aws CLI is required but not found"
[[ -n "$instance_id" ]] || die "--id is required"
[[ -n "$ami_name" ]] || die "--name is required"

instance_state="$(aws "${aws_options[@]}" ec2 describe-instances \
  --instance-ids "$instance_id" \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text)"
case "$instance_state" in
  terminated | shutting-down)
    die "instance $instance_id is in non-imageable state: $instance_state"
    ;;
esac

create_cmd=(aws "${aws_options[@]}" ec2 create-image --instance-id "$instance_id" --name "$ami_name")
[[ -n "$description" ]] && create_cmd+=(--description "$description")
$no_reboot && create_cmd+=(--no-reboot)

if $dry_run; then
  run_cmd "${create_cmd[@]}"
  log "dry-run mode: AMI not created"
  exit 0
fi

image_id="$("${create_cmd[@]}" --query 'ImageId' --output text)"
[[ -n "$image_id" && "$image_id" != "None" ]] || die "failed to obtain ImageId from create-image"
log "created AMI: $image_id"

if ((${#tag_pairs[@]} > 0)); then
  tag_args=()
  for pair in "${tag_pairs[@]}"; do
    parse_tag_pair "$pair"
    tag_args+=("Key=${tag_key},Value=${tag_value}")
  done

  run_cmd aws "${aws_options[@]}" ec2 create-tags --resources "$image_id" --tags "${tag_args[@]}"
  log "applied tags to AMI $image_id"
fi

if $wait_enabled; then
  wait_for_ami_available "$image_id"
  log "AMI is available: $image_id"
fi

printf '%s\n' "$image_id"
exit 0
