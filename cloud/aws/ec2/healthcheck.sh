#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: healthcheck.sh [OPTIONS]

Validate AWS EC2 automation readiness for this environment.

Options:
  --region REGION        AWS region override
  --profile PROFILE      AWS CLI profile
  --instance-id ID       Optional instance ID to validate reachability/state
  --strict               Treat WARN checks as failure
  --json                 Emit JSON report
  -h, --help             Show help
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

validate_instance_id() {
  [[ "$1" =~ ^i-[a-f0-9]{8,17}$ ]]
}

add_check() {
  checks_name+=("$1")
  checks_status+=("$2")
  checks_detail+=("$3")
}

output_text() {
  local i
  printf '%-30s %-8s %s\n' "CHECK" "STATUS" "DETAIL"
  printf '%-30s %-8s %s\n' "-----" "------" "------"
  for i in "${!checks_name[@]}"; do
    printf '%-30s %-8s %s\n' "${checks_name[$i]}" "${checks_status[$i]}" "${checks_detail[$i]}"
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

aws_options=()
instance_id=""
strict_mode=false
json_mode=false
checks_name=()
checks_status=()
checks_detail=()

while (($#)); do
  case "$1" in
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
    --instance-id)
      shift
      (($#)) || die "--instance-id requires a value"
      validate_instance_id "$1" || die "invalid instance ID: $1"
      instance_id="$1"
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

if command_exists aws; then
  add_check "cmd:aws" "PASS" "aws CLI found"
else
  add_check "cmd:aws" "FAIL" "aws CLI not found"
fi

if command_exists aws; then
  identity_line="$(aws "${aws_options[@]}" sts get-caller-identity --query '[Account,Arn]' --output text 2> /dev/null || true)"
  if [[ -n "$identity_line" && "$identity_line" != "None" ]]; then
    add_check "auth:sts" "PASS" "$identity_line"
  else
    add_check "auth:sts" "FAIL" "unable to call sts get-caller-identity"
  fi

  region_value="$(aws "${aws_options[@]}" configure get region 2> /dev/null || true)"
  if [[ -n "$region_value" ]]; then
    add_check "config:region" "PASS" "$region_value"
  else
    add_check "config:region" "WARN" "no default region configured (use --region)"
  fi

  if aws "${aws_options[@]}" ec2 describe-regions --all-regions --query 'Regions[0].RegionName' --output text > /dev/null 2>&1; then
    add_check "perm:ec2-describe-regions" "PASS" "allowed"
  else
    add_check "perm:ec2-describe-regions" "FAIL" "not allowed"
  fi

  instance_count="$(aws "${aws_options[@]}" ec2 describe-instances --query 'length(Reservations[].Instances[])' --output text 2> /dev/null || true)"
  if [[ "$instance_count" =~ ^[0-9]+$ ]]; then
    if ((instance_count > 0)); then
      add_check "ec2:instance-count" "PASS" "$instance_count instance(s) visible"
    else
      add_check "ec2:instance-count" "WARN" "no instances found in scope"
    fi
  else
    add_check "ec2:instance-count" "FAIL" "failed to query instance inventory"
  fi

  if [[ -n "$instance_id" ]]; then
    state="$(aws "${aws_options[@]}" ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].State.Name' --output text 2> /dev/null || true)"
    if [[ -z "$state" || "$state" == "None" ]]; then
      add_check "ec2:instance:$instance_id" "FAIL" "instance not found or inaccessible"
    else
      add_check "ec2:instance:$instance_id" "PASS" "state=$state"
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
