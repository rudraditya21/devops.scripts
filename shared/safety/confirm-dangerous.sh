#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: confirm-dangerous.sh [OPTIONS]

Prompt for explicit confirmation before dangerous operations.

Options:
  --message TEXT       Message shown before prompt
  --prompt TEXT        Prompt text (default includes expected token)
  --expect TOKEN       Required confirmation input (default: CONFIRM)
  -y, --yes            Bypass prompt and confirm immediately
  --timeout SEC        Read timeout in seconds (default: 0, disabled)
  -h, --help           Show help

Environment:
  CONFIRM_DANGEROUS    If set to 1/true/yes/on, confirmation is auto-approved.
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

is_non_negative_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

is_truthy() {
  case "${1:-}" in
    1 | true | TRUE | yes | YES | on | ON) return 0 ;;
    *) return 1 ;;
  esac
}

message="This operation is potentially destructive."
expect_token="CONFIRM"
prompt_text=""
assume_yes=false
timeout="0"

while (($#)); do
  case "$1" in
    --message)
      shift
      (($#)) || die "--message requires a value"
      message="$1"
      ;;
    --prompt)
      shift
      (($#)) || die "--prompt requires a value"
      prompt_text="$1"
      ;;
    --expect)
      shift
      (($#)) || die "--expect requires a value"
      [[ -n "$1" ]] || die "--expect cannot be empty"
      expect_token="$1"
      ;;
    --timeout)
      shift
      (($#)) || die "--timeout requires a value"
      is_non_negative_integer "$1" || die "--timeout must be a non-negative integer"
      timeout="$1"
      ;;
    -y | --yes)
      assume_yes=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      die "unexpected argument: $1"
      ;;
  esac
  shift
done

if [[ -z "$prompt_text" ]]; then
  prompt_text="Type '$expect_token' to continue"
fi

if $assume_yes || is_truthy "${CONFIRM_DANGEROUS:-}"; then
  printf 'Confirmation accepted (non-interactive override).\n' >&2
  exit 0
fi

if [[ ! -t 0 ]]; then
  printf 'ERROR: interactive confirmation required; use --yes only in audited non-interactive flows.\n' >&2
  exit 1
fi

printf '%s\n' "$message" >&2
printf '%s: ' "$prompt_text" >&2

input=""
if ((timeout > 0)); then
  if ! read -r -t "$timeout" input; then
    printf '\nERROR: confirmation timed out after %ss.\n' "$timeout" >&2
    exit 1
  fi
else
  if ! read -r input; then
    printf '\nERROR: failed to read confirmation input.\n' >&2
    exit 1
  fi
fi

if [[ "$input" != "$expect_token" ]]; then
  printf 'ERROR: confirmation mismatch; operation cancelled.\n' >&2
  exit 1
fi

printf 'Confirmation accepted.\n' >&2
