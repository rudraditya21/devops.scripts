#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'EOF'
Usage: require-env.sh [--allow-empty VAR]... [--quiet] [--json] VAR [VAR...]

Verifies that required environment variables are set.
By default variables must be set and non-empty.
Use --allow-empty for variables that may be set to empty values.

Exit code:
  0 if all requirements are met
  1 if any requirement fails
EOF
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

is_valid_var_name() {
  [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

in_list() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

allow_empty_vars=()
quiet=false
json_mode=false

while (($#)); do
  case "$1" in
    --allow-empty)
      shift
      (($#)) || die "--allow-empty requires a variable name"
      is_valid_var_name "$1" || die "invalid variable name for --allow-empty: $1"
      allow_empty_vars+=("$1")
      ;;
    --quiet) quiet=true ;;
    --json) json_mode=true ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      break
      ;;
  esac
  shift
done

(($#)) || die "at least one VAR is required"

required=()
missing=()
empty=()
present=()

for var_name in "$@"; do
  is_valid_var_name "$var_name" || die "invalid variable name: $var_name"
  required+=("$var_name")

  if [[ -z "${!var_name+x}" ]]; then
    missing+=("$var_name")
    continue
  fi

  if [[ -z "${!var_name}" ]] && ! in_list "$var_name" "${allow_empty_vars[@]}"; then
    empty+=("$var_name")
    continue
  fi

  present+=("$var_name")
done

if $json_mode; then
  printf '{'

  printf '"required":['
  for i in "${!required[@]}"; do
    (("$i" > 0)) && printf ','
    printf '"%s"' "$(json_escape "${required[$i]}")"
  done
  printf '],'

  printf '"present":['
  for i in "${!present[@]}"; do
    (("$i" > 0)) && printf ','
    printf '"%s"' "$(json_escape "${present[$i]}")"
  done
  printf '],'

  printf '"missing":['
  for i in "${!missing[@]}"; do
    (("$i" > 0)) && printf ','
    printf '"%s"' "$(json_escape "${missing[$i]}")"
  done
  printf '],'

  printf '"empty":['
  for i in "${!empty[@]}"; do
    (("$i" > 0)) && printf ','
    printf '"%s"' "$(json_escape "${empty[$i]}")"
  done
  printf ']'

  printf '}\n'
else
  if ((${#missing[@]} > 0)); then
    printf 'Missing environment variable(s): %s\n' "${missing[*]}" >&2
  fi
  if ((${#empty[@]} > 0)); then
    printf 'Empty environment variable(s): %s\n' "${empty[*]}" >&2
  fi
  if ((${#missing[@]} == 0 && ${#empty[@]} == 0)) && ! $quiet; then
    printf 'All required environment variables are valid: %s\n' "${required[*]}"
  fi
fi

if ((${#missing[@]} > 0 || ${#empty[@]} > 0)); then
  exit 1
fi
