#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: verify.sh [OPTIONS]

Verify integrity and presence of a vm backup artifact.

Options:
  --backup PATH          Backup artifact to verify (required)
  --checksum-file PATH   Optional checksum file path (default: <backup>.sha256)
  --json                 Emit JSON output
  -h, --help             Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

sha256_verify() {
  local checksum_file="$1"
  if command -v sha256sum > /dev/null 2>&1; then
    sha256sum -c "$checksum_file" > /dev/null 2>&1
  elif command -v shasum > /dev/null 2>&1; then
    shasum -a 256 -c "$checksum_file" > /dev/null 2>&1
  else
    return 2
  fi
}

backup_path=""
checksum_file=""
json=false

while (($#)); do
  case "$1" in
    --backup) shift; (($#)) || die "--backup requires a value"; backup_path="$1" ;;
    --checksum-file) shift; (($#)) || die "--checksum-file requires a value"; checksum_file="$1" ;;
    --json) json=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$backup_path" ]] || die "--backup is required"
[[ -n "$checksum_file" ]] || checksum_file="$backup_path.sha256"

exists=false
non_empty=false
checksum="SKIP"
detail=""

if [[ -e "$backup_path" ]]; then
  exists=true
  if [[ -s "$backup_path" || -d "$backup_path" ]]; then
    non_empty=true
  fi
else
  detail="backup path missing"
fi

if [[ -f "$checksum_file" ]]; then
  if sha256_verify "$checksum_file"; then
    checksum="PASS"
  else
    case "$?" in
      2) checksum="WARN"; detail="checksum tool unavailable" ;;
      *) checksum="FAIL"; detail="checksum verification failed" ;;
    esac
  fi
fi

status="PASS"
if [[ "$exists" != true || "$non_empty" != true ]]; then
  status="FAIL"
elif [[ "$checksum" == "FAIL" ]]; then
  status="FAIL"
elif [[ "$checksum" == "WARN" ]]; then
  status="WARN"
fi

if $json; then
  printf '{"category":"vm","backup":"%s","status":"%s","exists":%s,"non_empty":%s,"checksum":"%s","detail":"%s"}\n' \
    "$(json_escape "$backup_path")" \
    "$(json_escape "$status")" \
    "$exists" \
    "$non_empty" \
    "$(json_escape "$checksum")" \
    "$(json_escape "$detail")"
else
  printf 'category: %s\n' "vm"
  printf 'backup: %s\n' "$backup_path"
  printf 'status: %s\n' "$status"
  printf 'exists: %s\n' "$exists"
  printf 'non_empty: %s\n' "$non_empty"
  printf 'checksum: %s\n' "$checksum"
  [[ -n "$detail" ]] && printf 'detail: %s\n' "$detail"
fi

[[ "$status" == "PASS" || "$status" == "WARN" ]] || exit 1
exit 0
