#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'EOF'
Usage: parse-args.sh [--output json|kv] [--] ARGUMENTS...

Parses CLI-style arguments and emits structured output.

Supported forms:
  --flag                  => boolean true
  --no-flag               => boolean false
  --key value             => key="value"
  --key=value             => key="value"
  -k value                => k="value"
  -k=value                => k="value"
  -abc                    => a=true, b=true, c=true
  --                       end of options marker

Notes:
  - If a value starts with "-", prefer --key=value form.
  - Repeated keys are preserved as arrays in JSON output.
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

is_valid_long_key() {
  [[ "$1" =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]]
}

is_valid_short_key() {
  [[ "$1" =~ ^[A-Za-z0-9]$ ]]
}

bool_true="__BOOL_TRUE__"
bool_false="__BOOL_FALSE__"
value_separator=$'\037'

option_keys=()
option_values=()
option_counts=()
positionals=()

find_key_index() {
  local key="$1"
  local i
  for ((i = 0; i < ${#option_keys[@]}; i++)); do
    if [[ "${option_keys[$i]}" == "$key" ]]; then
      printf '%s' "$i"
      return 0
    fi
  done
  return 1
}

store_option() {
  local key="$1"
  local value="$2"
  local idx

  if idx="$(find_key_index "$key")"; then
    option_values[idx]="${option_values[idx]}${value_separator}${value}"
    option_counts[idx]=$((option_counts[idx] + 1))
  else
    option_keys+=("$key")
    option_values+=("$value")
    option_counts+=(1)
  fi
}

render_json_scalar() {
  local value="$1"
  if [[ "$value" == "$bool_true" ]]; then
    printf 'true'
  elif [[ "$value" == "$bool_false" ]]; then
    printf 'false'
  else
    printf '"%s"' "$(json_escape "$value")"
  fi
}

render_kv_scalar() {
  local value="$1"
  if [[ "$value" == "$bool_true" ]]; then
    printf 'true'
  elif [[ "$value" == "$bool_false" ]]; then
    printf 'false'
  else
    printf '%q' "$value"
  fi
}

output_format="json"

while (($#)); do
  case "$1" in
    --output)
      shift
      (($#)) || die "--output requires a value"
      case "$1" in
        json | kv) output_format="$1" ;;
        *) die "invalid output format: $1 (expected json or kv)" ;;
      esac
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown parser option: $1"
      ;;
    *)
      break
      ;;
  esac
  shift
done

(($#)) || die "ARGUMENTS are required (pass target args after --)"

args=("$@")
i=0
while ((i < ${#args[@]})); do
  token="${args[$i]}"

  case "$token" in
    --)
      i=$((i + 1))
      while ((i < ${#args[@]})); do
        positionals+=("${args[$i]}")
        i=$((i + 1))
      done
      break
      ;;
    --no-*)
      key="${token#--no-}"
      is_valid_long_key "$key" || die "invalid option name: $token"
      store_option "$key" "$bool_false"
      ;;
    --*=*)
      key="${token%%=*}"
      key="${key#--}"
      value="${token#*=}"
      is_valid_long_key "$key" || die "invalid option name: $token"
      store_option "$key" "$value"
      ;;
    --*)
      key="${token#--}"
      is_valid_long_key "$key" || die "invalid option name: $token"
      if ((i + 1 < ${#args[@]})) && [[ "${args[$((i + 1))]}" != -* ]]; then
        value="${args[$((i + 1))]}"
        store_option "$key" "$value"
        i=$((i + 1))
      else
        store_option "$key" "$bool_true"
      fi
      ;;
    -[A-Za-z0-9]=*)
      key="${token:1:1}"
      value="${token#*=}"
      is_valid_short_key "$key" || die "invalid short option: $token"
      store_option "$key" "$value"
      ;;
    -[A-Za-z0-9])
      key="${token:1:1}"
      is_valid_short_key "$key" || die "invalid short option: $token"
      if ((i + 1 < ${#args[@]})) && [[ "${args[$((i + 1))]}" != -* ]]; then
        value="${args[$((i + 1))]}"
        store_option "$key" "$value"
        i=$((i + 1))
      else
        store_option "$key" "$bool_true"
      fi
      ;;
    -[A-Za-z0-9][A-Za-z0-9]*)
      cluster="${token#-}"
      for ((j = 0; j < ${#cluster}; j++)); do
        key="${cluster:j:1}"
        is_valid_short_key "$key" || die "invalid short option cluster: $token"
        store_option "$key" "$bool_true"
      done
      ;;
    -*)
      die "unsupported option syntax: $token"
      ;;
    *)
      positionals+=("$token")
      ;;
  esac

  i=$((i + 1))
done

if [[ "$output_format" == "kv" ]]; then
  for ((i = 0; i < ${#option_keys[@]}; i++)); do
    key="${option_keys[$i]}"
    if ((${option_counts[$i]} == 1)); then
      printf 'opt.%s=' "$key"
      render_kv_scalar "${option_values[$i]}"
      printf '\n'
      continue
    fi

    IFS="$value_separator" read -r -a values <<< "${option_values[$i]}"
    for j in "${!values[@]}"; do
      printf 'opt.%s[%s]=' "$key" "$j"
      render_kv_scalar "${values[$j]}"
      printf '\n'
    done
  done

  for i in "${!positionals[@]}"; do
    printf 'positional[%s]=%q\n' "$i" "${positionals[$i]}"
  done
  printf 'positional_count=%s\n' "${#positionals[@]}"
  exit 0
fi

printf '{'
printf '"options":{'
for ((i = 0; i < ${#option_keys[@]}; i++)); do
  (("$i" > 0)) && printf ','
  key="${option_keys[$i]}"
  printf '"%s":' "$(json_escape "$key")"

  if ((${option_counts[$i]} == 1)); then
    render_json_scalar "${option_values[$i]}"
  else
    IFS="$value_separator" read -r -a values <<< "${option_values[$i]}"
    printf '['
    for j in "${!values[@]}"; do
      (("$j" > 0)) && printf ','
      render_json_scalar "${values[$j]}"
    done
    printf ']'
  fi
done
printf '},'

printf '"positionals":['
for i in "${!positionals[@]}"; do
  (("$i" > 0)) && printf ','
  printf '"%s"' "$(json_escape "${positionals[$i]}")"
done
printf ']'

printf '}\n'
