#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: verify-workstation.sh [OPTIONS]

Run workstation readiness checks for devops.scripts.

Options:
  --json                  Emit JSON report
  --strict                Fail on WARN as well as FAIL
  --required-cmds CSV     Override default required command list
  --required-cmd NAME     Add one required command (repeatable)
  -h, --help              Show help
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

get_perm() {
  local p="$1"
  if stat -f '%Lp' "$p" > /dev/null 2>&1; then
    stat -f '%Lp' "$p"
  else
    stat -c '%a' "$p"
  fi
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

output_text() {
  local i
  printf '%-28s %-8s %s\n' "CHECK" "STATUS" "DETAIL"
  printf '%-28s %-8s %s\n' "-----" "------" "------"
  for i in "${!checks_name[@]}"; do
    printf '%-28s %-8s %s\n' "${checks_name[$i]}" "${checks_status[$i]}" "${checks_detail[$i]}"
  done
  printf '\nSummary: PASS=%s WARN=%s FAIL=%s\n' "$pass_count" "$warn_count" "$fail_count"
}

json_mode=false
strict_mode=false
required_cmds=(bash git curl jq yq shellcheck shfmt kubectl terraform ssh gpg)
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

for cmd in "${required_cmds[@]}"; do
  if command_exists "$cmd"; then
    add_check "cmd:$cmd" "PASS" "found at $(command -v "$cmd")"
  else
    add_check "cmd:$cmd" "FAIL" "not found in PATH"
  fi
done

if command_exists git; then
  git_name="$(git config --global --get user.name || true)"
  git_email="$(git config --global --get user.email || true)"
  if [[ -n "$git_name" ]]; then
    add_check "git:user.name" "PASS" "$git_name"
  else
    add_check "git:user.name" "WARN" "not configured"
  fi
  if [[ -n "$git_email" ]]; then
    add_check "git:user.email" "PASS" "$git_email"
  else
    add_check "git:user.email" "WARN" "not configured"
  fi
fi

if [[ -d "$HOME/.ssh" ]]; then
  perm="$(get_perm "$HOME/.ssh")"
  if [[ "$perm" -le 700 ]]; then
    add_check "ssh:dir-perm" "PASS" "$perm"
  else
    add_check "ssh:dir-perm" "WARN" "expected <=700, got $perm"
  fi
else
  add_check "ssh:dir" "WARN" "$HOME/.ssh missing"
fi

if [[ -d "$HOME/.gnupg" ]]; then
  perm="$(get_perm "$HOME/.gnupg")"
  if [[ "$perm" -le 700 ]]; then
    add_check "gpg:dir-perm" "PASS" "$perm"
  else
    add_check "gpg:dir-perm" "WARN" "expected <=700, got $perm"
  fi
else
  add_check "gpg:dir" "WARN" "$HOME/.gnupg missing"
fi

if [[ -f "$HOME/.kube/config" ]]; then
  add_check "kubectl:config" "PASS" "$HOME/.kube/config present"
else
  add_check "kubectl:config" "WARN" "$HOME/.kube/config missing"
fi

if [[ -f "$HOME/.terraformrc" ]]; then
  add_check "terraform:config" "PASS" "$HOME/.terraformrc present"
else
  add_check "terraform:config" "WARN" "$HOME/.terraformrc missing"
fi

pass_count=0
warn_count=0
fail_count=0
for s in "${checks_status[@]}"; do
  case "$s" in
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
