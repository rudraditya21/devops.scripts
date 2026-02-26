#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'EOF'
Usage: json-output.sh [--pretty] [--infer-types] [--from-stdin] KEY=VALUE [KEY=VALUE...]

Builds a JSON object from key=value pairs.

Options:
  --pretty        Multi-line formatted JSON output
  --infer-types   Convert true/false/null/numbers from strings to JSON scalar types
  --from-stdin    Read key=value pairs from stdin (one pair per line)
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

is_valid_key() {
  [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]]
}

is_number() {
  [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?([eE][+-]?[0-9]+)?$ ]]
}

keys=()
values=()

find_key_index() {
  local key="$1"
  local i
  for ((i = 0; i < ${#keys[@]}; i++)); do
    if [[ "${keys[$i]}" == "$key" ]]; then
      printf '%s' "$i"
      return 0
    fi
  done
  return 1
}

set_pair() {
  local key="$1"
  local value="$2"
  local idx

  if idx="$(find_key_index "$key")"; then
    values[idx]="$value"
  else
    keys+=("$key")
    values+=("$value")
  fi
}

render_value() {
  local value="$1"
  if $infer_types; then
    case "$value" in
      true | false | null)
        printf '%s' "$value"
        return
        ;;
    esac
    if is_number "$value"; then
      printf '%s' "$value"
      return
    fi
  fi
  printf '"%s"' "$(json_escape "$value")"
}

pretty=false
infer_types=false
from_stdin=false

while (($#)); do
  case "$1" in
    --pretty) pretty=true ;;
    --infer-types) infer_types=true ;;
    --from-stdin) from_stdin=true ;;
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

pairs=()
if $from_stdin; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    pairs+=("$line")
  done
fi

if (($#)); then
  for arg in "$@"; do
    pairs+=("$arg")
  done
fi

((${#pairs[@]} > 0)) || die "no key=value pairs provided"

for pair in "${pairs[@]}"; do
  [[ "$pair" == *=* ]] || die "invalid pair (expected KEY=VALUE): $pair"
  key="${pair%%=*}"
  value="${pair#*=}"
  [[ -n "$key" ]] || die "invalid empty key in pair: $pair"
  is_valid_key "$key" || die "invalid key: $key"
  set_pair "$key" "$value"
done

if ! $pretty; then
  printf '{'
  for i in "${!keys[@]}"; do
    (("$i" > 0)) && printf ','
    printf '"%s":' "$(json_escape "${keys[$i]}")"
    render_value "${values[$i]}"
  done
  printf '}\n'
  exit 0
fi

printf '{\n'
for i in "${!keys[@]}"; do
  printf '  "%s": ' "$(json_escape "${keys[$i]}")"
  render_value "${values[$i]}"
  if (("$i" < ${#keys[@]} - 1)); then
    printf ',\n'
  else
    printf '\n'
  fi
done
printf '}\n'
