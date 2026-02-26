#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: audit-event.sh --action ACTION [OPTIONS]

Emit a structured audit event in JSON format.

Options:
  --action TEXT         Action name (required)
  --actor TEXT          Actor identity (default: AUDIT_ACTOR or USER)
  --target TEXT         Target resource identifier
  --status VALUE        Event status: info|success|failure|warning (default: info)
  --message TEXT        Human-readable event message
  --event-id ID         Explicit event id (default: generated)
  --source TEXT         Source component (default: script basename)
  --meta KEY=VALUE      Attach metadata pair (repeatable)
  --timestamp-format F  date format for timestamp (default: %Y-%m-%dT%H:%M:%S%z)
  --output FILE         Append JSON event to file instead of stdout
  --pretty              Render multi-line JSON
  -h, --help            Show help
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

valid_meta_key() {
  [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]]
}

set_meta_pair() {
  local key="$1"
  local value="$2"
  local i
  for ((i = 0; i < ${#meta_keys[@]}; i++)); do
    if [[ "${meta_keys[$i]}" == "$key" ]]; then
      meta_values[i]="$value"
      return
    fi
  done
  meta_keys+=("$key")
  meta_values+=("$value")
}

render_meta_compact() {
  local i
  printf '{'
  for i in "${!meta_keys[@]}"; do
    ((i > 0)) && printf ','
    printf '"%s":"%s"' "$(json_escape "${meta_keys[$i]}")" "$(json_escape "${meta_values[$i]}")"
  done
  printf '}'
}

render_meta_pretty() {
  local i
  if ((${#meta_keys[@]} == 0)); then
    printf '{}'
    return
  fi

  printf '{\n'
  for i in "${!meta_keys[@]}"; do
    printf '    "%s": "%s"' "$(json_escape "${meta_keys[$i]}")" "$(json_escape "${meta_values[$i]}")"
    if ((i < ${#meta_keys[@]} - 1)); then
      printf ',\n'
    else
      printf '\n'
    fi
  done
  printf '  }'
}

action=""
actor="${AUDIT_ACTOR:-${USER:-unknown}}"
target=""
status="info"
message=""
event_id=""
source_component="$(basename "$0" .sh)"
timestamp_format="%Y-%m-%dT%H:%M:%S%z"
output_file=""
pretty=false
meta_keys=()
meta_values=()

while (($#)); do
  case "$1" in
    --action)
      shift
      (($#)) || die "--action requires a value"
      action="$1"
      ;;
    --actor)
      shift
      (($#)) || die "--actor requires a value"
      actor="$1"
      ;;
    --target)
      shift
      (($#)) || die "--target requires a value"
      target="$1"
      ;;
    --status)
      shift
      (($#)) || die "--status requires a value"
      case "$1" in
        info | success | failure | warning) status="$1" ;;
        *) die "--status must be one of: info, success, failure, warning" ;;
      esac
      ;;
    --message)
      shift
      (($#)) || die "--message requires a value"
      message="$1"
      ;;
    --event-id)
      shift
      (($#)) || die "--event-id requires a value"
      event_id="$1"
      ;;
    --source)
      shift
      (($#)) || die "--source requires a value"
      source_component="$1"
      ;;
    --timestamp-format)
      shift
      (($#)) || die "--timestamp-format requires a value"
      timestamp_format="$1"
      ;;
    --meta)
      shift
      (($#)) || die "--meta requires KEY=VALUE"
      [[ "$1" == *=* ]] || die "--meta requires KEY=VALUE"
      meta_key="${1%%=*}"
      meta_value="${1#*=}"
      valid_meta_key "$meta_key" || die "invalid metadata key: $meta_key"
      set_meta_pair "$meta_key" "$meta_value"
      ;;
    --output)
      shift
      (($#)) || die "--output requires a file path"
      output_file="$1"
      ;;
    --pretty)
      pretty=true
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

[[ -n "$action" ]] || die "--action is required"
[[ -n "$event_id" ]] || event_id="ae-$(date +%s)-$$-$RANDOM"

timestamp="$(date +"$timestamp_format")" || die "failed to format timestamp"

if ! $pretty; then
  json_line="$(
    printf '{'
    printf '"timestamp":"%s",' "$(json_escape "$timestamp")"
    printf '"event_id":"%s",' "$(json_escape "$event_id")"
    printf '"actor":"%s",' "$(json_escape "$actor")"
    printf '"action":"%s",' "$(json_escape "$action")"
    printf '"target":"%s",' "$(json_escape "$target")"
    printf '"status":"%s",' "$(json_escape "$status")"
    printf '"message":"%s",' "$(json_escape "$message")"
    printf '"source":"%s",' "$(json_escape "$source_component")"
    printf '"meta":%s' "$(render_meta_compact)"
    printf '}'
  )"
else
  json_line="$(
    printf '{\n'
    printf '  "timestamp": "%s",\n' "$(json_escape "$timestamp")"
    printf '  "event_id": "%s",\n' "$(json_escape "$event_id")"
    printf '  "actor": "%s",\n' "$(json_escape "$actor")"
    printf '  "action": "%s",\n' "$(json_escape "$action")"
    printf '  "target": "%s",\n' "$(json_escape "$target")"
    printf '  "status": "%s",\n' "$(json_escape "$status")"
    printf '  "message": "%s",\n' "$(json_escape "$message")"
    printf '  "source": "%s",\n' "$(json_escape "$source_component")"
    printf '  "meta": '
    render_meta_pretty
    printf '\n}'
  )"
fi

if [[ -n "$output_file" ]]; then
  output_dir="$(dirname "$output_file")"
  [[ -d "$output_dir" ]] || die "output directory does not exist: $output_dir"
  printf '%s\n' "$json_line" >> "$output_file"
else
  printf '%s\n' "$json_line"
fi
