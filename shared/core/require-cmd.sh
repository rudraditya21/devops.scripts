#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'EOF'
Usage: require-cmd.sh [--quiet] [--json] COMMAND [COMMAND...]

Verifies that each required command is available in PATH.
Exit code:
  0 if all commands are available
  1 if one or more commands are missing
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

quiet=false
json_mode=false

while (($#)); do
  case "$1" in
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

(($#)) || die "at least one COMMAND is required"

required=()
resolved=()
missing=()

for cmd in "$@"; do
  [[ -n "$cmd" ]] || die "command name cannot be empty"
  required+=("$cmd")
  if path="$(command -v "$cmd" 2> /dev/null)"; then
    resolved+=("$cmd=$path")
  else
    missing+=("$cmd")
  fi
done

if $json_mode; then
  printf '{'

  printf '"required":['
  for i in "${!required[@]}"; do
    (("$i" > 0)) && printf ','
    printf '"%s"' "$(json_escape "${required[$i]}")"
  done
  printf '],'

  printf '"missing":['
  for i in "${!missing[@]}"; do
    (("$i" > 0)) && printf ','
    printf '"%s"' "$(json_escape "${missing[$i]}")"
  done
  printf '],'

  printf '"resolved":['
  for i in "${!resolved[@]}"; do
    (("$i" > 0)) && printf ','
    cmd="${resolved[$i]%%=*}"
    path="${resolved[$i]#*=}"
    printf '{"command":"%s","path":"%s"}' "$(json_escape "$cmd")" "$(json_escape "$path")"
  done
  printf ']'

  printf '}\n'
else
  if ((${#missing[@]} > 0)); then
    printf 'Missing required command(s): %s\n' "${missing[*]}" >&2
  elif ! $quiet; then
    printf 'All required commands are available: %s\n' "${required[*]}"
  fi
fi

if ((${#missing[@]} > 0)); then
  exit 1
fi
