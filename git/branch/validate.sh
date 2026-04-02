#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: validate.sh [OPTIONS]

Validate branch values against policy.

Options:
  --value TEXT        Value to validate (required)
  --pattern REGEX     Validation regex (default: ^[A-Za-z0-9._/-]+$)
  --json              Emit JSON output
  --fail-on-invalid   Exit non-zero when invalid
  -h, --help          Show help
USAGE
}

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 2; }
json_escape(){ local s="${1-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }

value=""
pattern='^[A-Za-z0-9._/-]+$'
json=false
fail_on_invalid=false

while (($#)); do
  case "$1" in
    --value) shift; (($#)) || die "--value requires a value"; value="$1" ;;
    --pattern) shift; (($#)) || die "--pattern requires a value"; pattern="$1" ;;
    --json) json=true ;;
    --fail-on-invalid) fail_on_invalid=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$value" ]] || die "--value is required"

status="valid"
if [[ ! "$value" =~ $pattern ]]; then
  status="invalid"
fi

if $json; then
  printf '{"domain":"branch","action":"validate","value":"%s","pattern":"%s","status":"%s"}\n' \
    "$(json_escape "$value")" \
    "$(json_escape "$pattern")" \
    "$(json_escape "$status")"
else
  printf 'domain: branch\n'
  printf 'action: validate\n'
  printf 'value: %s\n' "$value"
  printf 'pattern: %s\n' "$pattern"
  printf 'status: %s\n' "$status"
fi

if $fail_on_invalid && [[ "$status" == "invalid" ]]; then
  exit 1
fi

exit 0
