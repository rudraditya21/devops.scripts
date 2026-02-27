#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: vpc-healthcheck.sh [OPTIONS]

Run preflight and posture checks for an AWS VPC.

Options:
  --vpc-id ID                    VPC ID (required)
  --expected-public-subnets N    Expected count of public subnets
  --expected-private-subnets N   Expected count of private subnets
  --require-nat                  Fail if no available NAT gateway
  --region REGION                AWS region
  --profile PROFILE              AWS CLI profile
  --strict                       Exit non-zero on WARN
  --json                         Emit JSON report
  -h, --help                     Show help
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

validate_vpc_id() {
  [[ "$1" =~ ^vpc-[a-f0-9]{8,17}$ ]]
}

add_check() {
  checks_name+=("$1")
  checks_status+=("$2")
  checks_detail+=("$3")
}

output_text() {
  local i
  printf '%-34s %-8s %s\n' "CHECK" "STATUS" "DETAIL"
  printf '%-34s %-8s %s\n' "-----" "------" "------"
  for i in "${!checks_name[@]}"; do
    printf '%-34s %-8s %s\n' "${checks_name[$i]}" "${checks_status[$i]}" "${checks_detail[$i]}"
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

vpc_id=""
expected_public=""
expected_private=""
require_nat=false
region=""
profile=""
strict_mode=false
json_mode=false
checks_name=()
checks_status=()
checks_detail=()

while (($#)); do
  case "$1" in
    --vpc-id)
      shift
      (($#)) || die "--vpc-id requires a value"
      validate_vpc_id "$1" || die "invalid VPC ID: $1"
      vpc_id="$1"
      ;;
    --expected-public-subnets)
      shift
      (($#)) || die "--expected-public-subnets requires a value"
      [[ "$1" =~ ^[0-9]+$ ]] || die "--expected-public-subnets must be a non-negative integer"
      expected_public="$1"
      ;;
    --expected-private-subnets)
      shift
      (($#)) || die "--expected-private-subnets requires a value"
      [[ "$1" =~ ^[0-9]+$ ]] || die "--expected-private-subnets must be a non-negative integer"
      expected_private="$1"
      ;;
    --require-nat)
      require_nat=true
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

[[ -n "$vpc_id" ]] || die "--vpc-id is required"

if command_exists aws; then
  add_check "cmd:aws" "PASS" "aws CLI found"
else
  add_check "cmd:aws" "FAIL" "aws CLI not found"
fi

aws_options=()
[[ -n "$region" ]] && aws_options+=(--region "$region")
[[ -n "$profile" ]] && aws_options+=(--profile "$profile")

if command_exists aws && aws "${aws_options[@]}" ec2 describe-vpcs --vpc-ids "$vpc_id" > /dev/null 2>&1; then
  add_check "vpc:exists" "PASS" "$vpc_id"

  vpc_state="$(aws "${aws_options[@]}" ec2 describe-vpcs --vpc-ids "$vpc_id" --query 'Vpcs[0].State' --output text)"
  if [[ "$vpc_state" == "available" ]]; then
    add_check "vpc:state" "PASS" "$vpc_state"
  else
    add_check "vpc:state" "WARN" "$vpc_state"
  fi

  dns_support="$(aws "${aws_options[@]}" ec2 describe-vpc-attribute --vpc-id "$vpc_id" --attribute enableDnsSupport --query 'EnableDnsSupport.Value' --output text 2> /dev/null || true)"
  if [[ "$dns_support" == "True" || "$dns_support" == "true" ]]; then
    add_check "vpc:dns-support" "PASS" "enabled"
  else
    add_check "vpc:dns-support" "WARN" "disabled"
  fi

  dns_hostnames="$(aws "${aws_options[@]}" ec2 describe-vpc-attribute --vpc-id "$vpc_id" --attribute enableDnsHostnames --query 'EnableDnsHostnames.Value' --output text 2> /dev/null || true)"
  if [[ "$dns_hostnames" == "True" || "$dns_hostnames" == "true" ]]; then
    add_check "vpc:dns-hostnames" "PASS" "enabled"
  else
    add_check "vpc:dns-hostnames" "WARN" "disabled"
  fi

  igw_count="$(aws "${aws_options[@]}" ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values="$vpc_id" --query 'length(InternetGateways)' --output text)"
  if [[ "$igw_count" =~ ^[0-9]+$ ]] && ((igw_count > 0)); then
    add_check "vpc:internet-gateway" "PASS" "$igw_count attached"
  else
    add_check "vpc:internet-gateway" "WARN" "no internet gateway attached"
  fi

  total_subnets="$(aws "${aws_options[@]}" ec2 describe-subnets --filters Name=vpc-id,Values="$vpc_id" --query 'length(Subnets)' --output text)"
  # shellcheck disable=SC2016
  public_subnet_query='length(Subnets[?MapPublicIpOnLaunch==`true`])'
  public_subnets="$(aws "${aws_options[@]}" ec2 describe-subnets --filters Name=vpc-id,Values="$vpc_id" --query "$public_subnet_query" --output text)"
  [[ "$total_subnets" =~ ^[0-9]+$ ]] || total_subnets=0
  [[ "$public_subnets" =~ ^[0-9]+$ ]] || public_subnets=0
  private_subnets=$((total_subnets - public_subnets))

  if ((total_subnets > 0)); then
    add_check "subnets:total" "PASS" "$total_subnets"
  else
    add_check "subnets:total" "FAIL" "no subnets in VPC"
  fi

  if [[ -n "$expected_public" ]]; then
    if ((public_subnets == expected_public)); then
      add_check "subnets:public" "PASS" "expected=$expected_public actual=$public_subnets"
    else
      add_check "subnets:public" "WARN" "expected=$expected_public actual=$public_subnets"
    fi
  else
    add_check "subnets:public" "PASS" "$public_subnets"
  fi

  if [[ -n "$expected_private" ]]; then
    if ((private_subnets == expected_private)); then
      add_check "subnets:private" "PASS" "expected=$expected_private actual=$private_subnets"
    else
      add_check "subnets:private" "WARN" "expected=$expected_private actual=$private_subnets"
    fi
  else
    add_check "subnets:private" "PASS" "$private_subnets"
  fi

  nat_available="$(aws "${aws_options[@]}" ec2 describe-nat-gateways --filter Name=vpc-id,Values="$vpc_id" Name=state,Values=available --query 'length(NatGateways)' --output text 2> /dev/null || echo 0)"
  nat_pending="$(aws "${aws_options[@]}" ec2 describe-nat-gateways --filter Name=vpc-id,Values="$vpc_id" Name=state,Values=pending --query 'length(NatGateways)' --output text 2> /dev/null || echo 0)"
  [[ "$nat_available" =~ ^[0-9]+$ ]] || nat_available=0
  [[ "$nat_pending" =~ ^[0-9]+$ ]] || nat_pending=0

  if ((nat_available > 0)); then
    add_check "nat:available" "PASS" "$nat_available available"
  else
    if $require_nat; then
      add_check "nat:available" "FAIL" "no available NAT gateway"
    else
      add_check "nat:available" "WARN" "no available NAT gateway"
    fi
  fi

  if ((nat_pending > 0)); then
    add_check "nat:pending" "WARN" "$nat_pending pending"
  else
    add_check "nat:pending" "PASS" "0"
  fi

  route_table_count="$(aws "${aws_options[@]}" ec2 describe-route-tables --filters Name=vpc-id,Values="$vpc_id" --query 'length(RouteTables)' --output text)"
  [[ "$route_table_count" =~ ^[0-9]+$ ]] || route_table_count=0
  if ((route_table_count > 0)); then
    add_check "route-tables:count" "PASS" "$route_table_count"
  else
    add_check "route-tables:count" "FAIL" "no route tables found"
  fi
else
  add_check "vpc:exists" "FAIL" "VPC not found or inaccessible: $vpc_id"
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
