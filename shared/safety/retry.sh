#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: retry.sh [OPTIONS] -- COMMAND [ARGS...]

Retry a command on failure with configurable backoff.

Options:
  --attempts N         Total attempts (default: 3)
  --delay SEC          Initial delay before retry (default: 1)
  --backoff FACTOR     Delay multiplier per retry (default: 2)
  --max-delay SEC      Upper cap for delay (default: 0, disabled)
  --jitter PERCENT     Add up to PERCENT% positive jitter (default: 0)
  --retry-on CODES     Comma-separated exit codes to retry (default: all non-zero)
  --quiet              Suppress retry logs
  -h, --help           Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  if ! $quiet; then
    printf '%s [retry] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
  fi
}

is_non_negative_number() {
  [[ "$1" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

should_retry_status() {
  local status="$1"
  if $retry_on_all; then
    return 0
  fi

  local code
  for code in "${retry_codes[@]}"; do
    if [[ "$code" == "$status" ]]; then
      return 0
    fi
  done
  return 1
}

calc_with_cap() {
  local value="$1"
  local cap="$2"

  if [[ "$cap" == "0" ]]; then
    printf '%s' "$value"
    return
  fi

  awk -v v="$value" -v c="$cap" 'BEGIN { if (v > c) printf "%.6f", c; else printf "%.6f", v }'
}

calc_next_delay() {
  local current="$1"
  local base
  base="$(awk -v d="$current" -v b="$backoff" 'BEGIN { printf "%.6f", d * b }')"
  base="$(calc_with_cap "$base" "$max_delay")"

  if [[ "$jitter" == "0" ]]; then
    printf '%s' "$base"
    return
  fi

  local rand_fraction jitter_amount
  rand_fraction="$(awk -v r="$RANDOM" 'BEGIN { printf "%.6f", r / 32767 }')"
  jitter_amount="$(awk -v d="$base" -v p="$jitter" -v rf="$rand_fraction" 'BEGIN { printf "%.6f", d * (p / 100.0) * rf }')"
  awk -v d="$base" -v j="$jitter_amount" 'BEGIN { printf "%.6f", d + j }'
}

attempts=3
delay="1"
backoff="2"
max_delay="0"
jitter="0"
retry_on_all=true
retry_codes=()
quiet=false
command=()

while (($#)); do
  case "$1" in
    --attempts)
      shift
      (($#)) || die "--attempts requires a value"
      is_positive_integer "$1" || die "--attempts must be a positive integer"
      attempts="$1"
      ;;
    --delay)
      shift
      (($#)) || die "--delay requires a value"
      is_non_negative_number "$1" || die "--delay must be a non-negative number"
      delay="$1"
      ;;
    --backoff)
      shift
      (($#)) || die "--backoff requires a value"
      is_non_negative_number "$1" || die "--backoff must be a non-negative number"
      backoff="$1"
      ;;
    --max-delay)
      shift
      (($#)) || die "--max-delay requires a value"
      is_non_negative_number "$1" || die "--max-delay must be a non-negative number"
      max_delay="$1"
      ;;
    --jitter)
      shift
      (($#)) || die "--jitter requires a value"
      is_non_negative_number "$1" || die "--jitter must be a non-negative number"
      jitter="$1"
      ;;
    --retry-on)
      shift
      (($#)) || die "--retry-on requires a value"
      retry_on_all=false
      IFS=',' read -r -a retry_codes <<< "$1"
      ((${#retry_codes[@]} > 0)) || die "--retry-on must include at least one code"
      for code in "${retry_codes[@]}"; do
        [[ "$code" =~ ^[0-9]+$ ]] || die "retry code must be numeric: $code"
        ((code >= 1 && code <= 255)) || die "retry code must be in range 1..255: $code"
      done
      ;;
    --quiet)
      quiet=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      command=("$@")
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      command=("$@")
      break
      ;;
  esac
  shift
done

((${#command[@]} > 0)) || die "COMMAND is required (use -- COMMAND ...)"

attempt=1
current_delay="$delay"

while true; do
  log "attempt ${attempt}/${attempts}: ${command[*]}"

  set +e
  "${command[@]}"
  status=$?
  set -e

  if ((status == 0)); then
    log "command succeeded on attempt ${attempt}/${attempts}"
    exit 0
  fi

  if ! should_retry_status "$status"; then
    log "command failed with non-retryable status $status"
    exit "$status"
  fi

  if ((attempt >= attempts)); then
    log "command failed after ${attempts} attempts (status $status)"
    exit "$status"
  fi

  sleep_for="$current_delay"
  log "command failed with status $status; retrying in ${sleep_for}s"
  sleep "$sleep_for"

  current_delay="$(calc_next_delay "$current_delay")"
  attempt=$((attempt + 1))
done
