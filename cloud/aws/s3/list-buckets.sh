#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: list-buckets.sh [OPTIONS]

List S3 buckets with optional name prefix filtering and region enrichment.

Options:
  --region REGION      AWS region override for API calls
  --profile PROFILE    AWS CLI profile
  --prefix TEXT        Filter bucket names by prefix
  --with-region        Include resolved bucket region in output
  --output MODE        table|json|names (default: table)
  --dry-run            Print planned AWS commands only
  -h, --help           Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [list-buckets] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
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

aws_options=()
prefix=""
with_region=false
output_mode="table"
dry_run=false

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
    --prefix)
      shift
      (($#)) || die "--prefix requires a value"
      prefix="$1"
      ;;
    --with-region)
      with_region=true
      ;;
    --output)
      shift
      (($#)) || die "--output requires a value"
      case "$1" in
        table | json | names) output_mode="$1" ;;
        *) die "invalid --output value: $1 (expected table|json|names)" ;;
      esac
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

list_cmd=(aws "${aws_options[@]}" s3api list-buckets --query 'Buckets[].[Name,CreationDate]' --output text)
if $dry_run; then
  run_cmd "${list_cmd[@]}"
  if $with_region; then
    run_cmd aws "${aws_options[@]}" s3api get-bucket-location --bucket EXAMPLE
  fi
  exit 0
fi

rows=()
while IFS=$'\t' read -r bucket_name creation_date; do
  [[ -n "$bucket_name" ]] || continue

  if [[ -n "$prefix" && "$bucket_name" != "$prefix"* ]]; then
    continue
  fi

  bucket_region=""
  if $with_region; then
    bucket_region="$(aws "${aws_options[@]}" s3api get-bucket-location --bucket "$bucket_name" --query 'LocationConstraint' --output text 2> /dev/null || true)"
    case "$bucket_region" in
      None | null | '') bucket_region="us-east-1" ;;
      EU) bucket_region="eu-west-1" ;;
    esac
  fi

  rows+=("$bucket_name|$creation_date|$bucket_region")
done < <("${list_cmd[@]}")

case "$output_mode" in
  names)
    for row in "${rows[@]}"; do
      printf '%s\n' "${row%%|*}"
    done
    ;;
  json)
    printf '['
    for i in "${!rows[@]}"; do
      ((i > 0)) && printf ','
      row="${rows[$i]}"
      name="${row%%|*}"
      rest="${row#*|}"
      creation="${rest%%|*}"
      region="${row##*|}"

      printf '{"Name":"%s","CreationDate":"%s"' "$name" "$creation"
      if [[ -n "$region" ]]; then
        printf ',"Region":"%s"' "$region"
      fi
      printf '}'
    done
    printf ']\n'
    ;;
  table)
    if $with_region; then
      printf '%-40s %-30s %-15s\n' "BUCKET" "CREATED" "REGION"
      printf '%-40s %-30s %-15s\n' "------" "-------" "------"
      for row in "${rows[@]}"; do
        name="${row%%|*}"
        rest="${row#*|}"
        creation="${rest%%|*}"
        region="${row##*|}"
        printf '%-40s %-30s %-15s\n' "$name" "$creation" "$region"
      done
    else
      printf '%-40s %-30s\n' "BUCKET" "CREATED"
      printf '%-40s %-30s\n' "------" "-------"
      for row in "${rows[@]}"; do
        name="${row%%|*}"
        rest="${row#*|}"
        creation="${rest%%|*}"
        printf '%-40s %-30s\n' "$name" "$creation"
      done
    fi
    ;;
esac

log "listed ${#rows[@]} bucket(s)"
exit 0
