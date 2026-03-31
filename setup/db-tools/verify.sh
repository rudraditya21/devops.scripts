#!/usr/bin/env bash
set -euo pipefail

usage(){ cat << 'USAGE'
Usage: verify.sh [OPTIONS]

Verify local database CLI tool readiness.

Options:
  --strict            Treat WARN as failure
  --json              Emit JSON report
  -h, --help          Show help
USAGE
}

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 2; }
command_exists(){ command -v "$1" > /dev/null 2>&1; }
json_escape(){ local s="${1-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }
add(){ n+=("$1"); s+=("$2"); d+=("$3"); }

strict=false
json=false
n=(); s=(); d=()

while (($#)); do
  case "$1" in
    --strict) strict=true ;;
    --json) json=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

for c in psql pg_dump mysql mysqldump; do
  if command_exists "$c"; then add "cmd:$c" PASS "found"; else add "cmd:$c" WARN "missing"; fi
done

[[ -f "$HOME/.pgpass" ]] && add pg:config PASS '~/.pgpass present' || add pg:config WARN '~/.pgpass missing'
[[ -f "$HOME/.my.cnf" ]] && add mysql:config PASS '~/.my.cnf present' || add mysql:config WARN '~/.my.cnf missing'

pass=0; warn=0; fail=0
for x in "${s[@]}"; do case "$x" in PASS) pass=$((pass+1));; WARN) warn=$((warn+1));; FAIL) fail=$((fail+1));; esac; done

if $json; then
  printf '{"summary":{"pass":%s,"warn":%s,"fail":%s},"checks":[' "$pass" "$warn" "$fail"
  for i in "${!n[@]}"; do
    ((i>0)) && printf ','
    printf '{"name":"%s","status":"%s","detail":"%s"}' "$(json_escape "${n[$i]}")" "$(json_escape "${s[$i]}")" "$(json_escape "${d[$i]}")"
  done
  printf ']}\n'
else
  printf '%-22s %-8s %s\n' CHECK STATUS DETAIL
  printf '%-22s %-8s %s\n' ----- ------ ------
  for i in "${!n[@]}"; do printf '%-22s %-8s %s\n' "${n[$i]}" "${s[$i]}" "${d[$i]}"; done
  printf '\nSummary: PASS=%s WARN=%s FAIL=%s\n' "$pass" "$warn" "$fail"
fi

((fail==0)) || exit 1
if $strict && ((warn>0)); then exit 1; fi
exit 0
