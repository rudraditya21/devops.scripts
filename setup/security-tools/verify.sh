#!/usr/bin/env bash
set -euo pipefail

usage(){ cat << 'USAGE'
Usage: verify.sh [OPTIONS]

Verify security tooling readiness on workstation/runner.

Options:
  --strict            Treat WARN as failure
  --json              Emit JSON report
  -h, --help          Show help
USAGE
}

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 2; }
command_exists(){ command -v "$1" > /dev/null 2>&1; }
json_escape(){ local s="${1-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }
add(){ n+=("$1"); st+=("$2"); dt+=("$3"); }

strict=false
json=false
n=(); st=(); dt=()

while (($#)); do
  case "$1" in
    --strict) strict=true ;;
    --json) json=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

for c in gpg ssh ssh-keygen openssl; do
  if command_exists "$c"; then add "cmd:$c" PASS "found"; else add "cmd:$c" WARN "missing"; fi
done

[[ -d "$HOME/.ssh" ]] && add ssh:dir PASS '~/.ssh present' || add ssh:dir WARN '~/.ssh missing'
[[ -d "$HOME/.gnupg" ]] && add gpg:dir PASS '~/.gnupg present' || add gpg:dir WARN '~/.gnupg missing'

pass=0; warn=0; fail=0
for x in "${st[@]}"; do case "$x" in PASS) pass=$((pass+1));; WARN) warn=$((warn+1));; FAIL) fail=$((fail+1));; esac; done

if $json; then
  printf '{"summary":{"pass":%s,"warn":%s,"fail":%s},"checks":[' "$pass" "$warn" "$fail"
  for i in "${!n[@]}"; do
    ((i>0)) && printf ','
    printf '{"name":"%s","status":"%s","detail":"%s"}' "$(json_escape "${n[$i]}")" "$(json_escape "${st[$i]}")" "$(json_escape "${dt[$i]}")"
  done
  printf ']}\n'
else
  printf '%-20s %-8s %s\n' CHECK STATUS DETAIL
  printf '%-20s %-8s %s\n' ----- ------ ------
  for i in "${!n[@]}"; do printf '%-20s %-8s %s\n' "${n[$i]}" "${st[$i]}" "${dt[$i]}"; done
  printf '\nSummary: PASS=%s WARN=%s FAIL=%s\n' "$pass" "$warn" "$fail"
fi

((fail==0)) || exit 1
if $strict && ((warn>0)); then exit 1; fi
exit 0
