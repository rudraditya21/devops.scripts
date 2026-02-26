#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: runner-healthcheck.sh [OPTIONS]

Validate runner readiness for devops.scripts automation.

Options:
  --json                Emit JSON report
  --strict              Treat WARN as failure
  --no-docker-check     Skip Docker checks
  --no-k8s-check        Skip Kubernetes tool checks
  --no-cloud-check      Skip cloud CLI checks
  --no-terraform-check  Skip Terraform check
  --no-gpg-check        Skip GPG check
  --required-cmds CSV   Override required command list
  --required-cmd NAME   Add one required command
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

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

add_check() {
  checks_name+=("$1")
  checks_status+=("$2")
  checks_detail+=("$3")
}

normalize_required_cmds() {
  local csv="$1"
  local item
  IFS=',' read -r -a parsed <<< "$csv"
  for item in "${parsed[@]}"; do
    item="$(printf '%s' "$item" | awk '{$1=$1; print}')"
    [[ -n "$item" ]] || continue
    required_cmds+=("$item")
  done
}

output_text() {
  local i
  printf '%-30s %-8s %s\n' "CHECK" "STATUS" "DETAIL"
  printf '%-30s %-8s %s\n' "-----" "------" "------"
  for i in "${!checks_name[@]}"; do
    printf '%-30s %-8s %s\n' "${checks_name[$i]}" "${checks_status[$i]}" "${checks_detail[$i]}"
  done
  printf '\nSummary: PASS=%s WARN=%s FAIL=%s\n' "$pass_count" "$warn_count" "$fail_count"
}

output_json() {
  local i
  printf '{'
  printf '"summary":{'
  printf '"pass":%s,' "$pass_count"
  printf '"warn":%s,' "$warn_count"
  printf '"fail":%s' "$fail_count"
  printf '},'
  printf '"checks":['
  for i in "${!checks_name[@]}"; do
    ((i > 0)) && printf ','
    printf '{'
    printf '"name":"%s",' "$(json_escape "${checks_name[$i]}")"
    printf '"status":"%s",' "$(json_escape "${checks_status[$i]}")"
    printf '"detail":"%s"' "$(json_escape "${checks_detail[$i]}")"
    printf '}'
  done
  printf ']'
  printf '}\n'
}

json_mode=false
strict_mode=false
check_docker=true
check_k8s=true
check_cloud=true
check_terraform=true
check_gpg=true
required_cmds=(bash git curl jq yq)
checks_name=()
checks_status=()
checks_detail=()

while (($#)); do
  case "$1" in
    --json)
      json_mode=true
      ;;
    --strict)
      strict_mode=true
      ;;
    --no-docker-check)
      check_docker=false
      ;;
    --no-k8s-check)
      check_k8s=false
      ;;
    --no-cloud-check)
      check_cloud=false
      ;;
    --no-terraform-check)
      check_terraform=false
      ;;
    --no-gpg-check)
      check_gpg=false
      ;;
    --required-cmds)
      shift
      (($#)) || die "--required-cmds requires a value"
      required_cmds=()
      normalize_required_cmds "$1"
      ;;
    --required-cmd)
      shift
      (($#)) || die "--required-cmd requires a value"
      required_cmds+=("$1")
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

os_name="$(uname -s)"
case "$os_name" in
  Linux | Darwin) add_check "os:supported" "PASS" "$os_name" ;;
  *) add_check "os:supported" "FAIL" "unsupported OS: $os_name" ;;
esac

if [[ -w "${TMPDIR:-/tmp}" ]]; then
  add_check "tmp:writable" "PASS" "${TMPDIR:-/tmp} is writable"
else
  add_check "tmp:writable" "FAIL" "${TMPDIR:-/tmp} is not writable"
fi

cmd=""
for cmd in "${required_cmds[@]}"; do
  if command_exists "$cmd"; then
    add_check "cmd:$cmd" "PASS" "found at $(command -v "$cmd")"
  else
    add_check "cmd:$cmd" "FAIL" "not found in PATH"
  fi
done

if $check_terraform; then
  if command_exists terraform; then
    add_check "terraform:binary" "PASS" "found"
  else
    add_check "terraform:binary" "FAIL" "terraform missing"
  fi
fi

if $check_docker; then
  if command_exists docker; then
    add_check "docker:binary" "PASS" "found"
    if docker info > /dev/null 2>&1; then
      add_check "docker:daemon" "PASS" "daemon reachable"
    else
      add_check "docker:daemon" "WARN" "binary found but daemon unreachable"
    fi
  else
    add_check "docker:binary" "FAIL" "docker missing"
  fi
fi

if $check_k8s; then
  if command_exists kubectl; then
    add_check "k8s:kubectl" "PASS" "found"
  else
    add_check "k8s:kubectl" "FAIL" "kubectl missing"
  fi

  if command_exists helm; then
    add_check "k8s:helm" "PASS" "found"
  else
    add_check "k8s:helm" "FAIL" "helm missing"
  fi
fi

if $check_cloud; then
  if command_exists aws; then
    add_check "cloud:aws" "PASS" "found"
  else
    add_check "cloud:aws" "WARN" "aws cli missing"
  fi

  if command_exists gcloud; then
    add_check "cloud:gcloud" "PASS" "found"
  else
    add_check "cloud:gcloud" "WARN" "gcloud cli missing"
  fi

  if command_exists az; then
    add_check "cloud:az" "PASS" "found"
  else
    add_check "cloud:az" "WARN" "azure cli missing"
  fi
fi

if $check_gpg; then
  if command_exists gpg; then
    add_check "gpg:binary" "PASS" "found"
  else
    add_check "gpg:binary" "WARN" "gpg missing"
  fi
fi

pass_count=0
warn_count=0
fail_count=0
status=""
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

exit 0
