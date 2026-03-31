#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: healthcheck.sh [OPTIONS]

Validate MySQL connectivity and basic query readiness.

Options:
  --host HOST              MySQL host (default: localhost)
  --port PORT              MySQL port (default: 3306)
  --user USER              Database user (required)
  --database NAME          Optional database for query check
  --strict                 Treat WARN as failure
  --json                   Emit JSON report
  -h, --help               Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
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

add_check() {
  checks_name+=("$1")
  checks_status+=("$2")
  checks_detail+=("$3")
}

output_text() {
  local i
  printf '%-28s %-8s %s\n' "CHECK" "STATUS" "DETAIL"
  printf '%-28s %-8s %s\n' "-----" "------" "------"
  for i in "${!checks_name[@]}"; do
    printf '%-28s %-8s %s\n' "${checks_name[$i]}" "${checks_status[$i]}" "${checks_detail[$i]}"
  done
  printf '\nSummary: PASS=%s WARN=%s FAIL=%s\n' "$pass_count" "$warn_count" "$fail_count"
}

output_json() {
  local i
  printf '{'
  printf '"summary":{"pass":%s,"warn":%s,"fail":%s},' "$pass_count" "$warn_count" "$fail_count"
  printf '"checks":['
  for i in "${!checks_name[@]}"; do
    ((i > 0)) && printf ','
    printf '{"name":"%s","status":"%s","detail":"%s"}' \
      "$(json_escape "${checks_name[$i]}")" \
      "$(json_escape "${checks_status[$i]}")" \
      "$(json_escape "${checks_detail[$i]}")"
  done
  printf ']}'
  printf '\n'
}

host="localhost"
port=3306
db_user=""
database=""
strict_mode=false
json_mode=false
checks_name=()
checks_status=()
checks_detail=()

while (($#)); do
  case "$1" in
    --host)
      shift
      (($#)) || die "--host requires a value"
      host="$1"
      ;;
    --port)
      shift
      (($#)) || die "--port requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--port must be a positive integer"
      port="$1"
      ;;
    --user)
      shift
      (($#)) || die "--user requires a value"
      db_user="$1"
      ;;
    --database)
      shift
      (($#)) || die "--database requires a value"
      database="$1"
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

[[ -n "$db_user" ]] || die "--user is required"

if command_exists mysqladmin; then
  add_check "cmd:mysqladmin" "PASS" "mysqladmin found"
  if mysqladmin --host "$host" --port "$port" --user "$db_user" ping > /dev/null 2>&1; then
    add_check "mysql:ping" "PASS" "$host:$port reachable"
  else
    add_check "mysql:ping" "FAIL" "$host:$port unreachable"
  fi
else
  add_check "cmd:mysqladmin" "WARN" "mysqladmin not found"
fi

if command_exists mysql; then
  add_check "cmd:mysql" "PASS" "mysql client found"
else
  add_check "cmd:mysql" "FAIL" "mysql client not found"
fi

if [[ -n "$database" ]] && command_exists mysql; then
  if mysql --host "$host" --port "$port" --user "$db_user" --database "$database" --batch --skip-column-names --execute 'SELECT 1' > /dev/null 2>&1; then
    add_check "mysql:query" "PASS" "query check succeeded"
  else
    add_check "mysql:query" "FAIL" "query check failed"
  fi
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
