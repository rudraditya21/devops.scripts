#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: verify.sh [OPTIONS]

Verify Kubernetes workstation readiness.

Options:
  --strict            Treat WARN as failure
  --json              Emit JSON report
  -h, --help          Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

command_exists(){ command -v "$1" > /dev/null 2>&1; }
add(){ names+=("$1"); stats+=("$2"); details+=("$3"); }

output_text(){
  local i
  printf '%-26s %-8s %s\n' CHECK STATUS DETAIL
  printf '%-26s %-8s %s\n' ----- ------ ------
  for i in "${!names[@]}"; do
    printf '%-26s %-8s %s\n' "${names[$i]}" "${stats[$i]}" "${details[$i]}"
  done
  printf '\nSummary: PASS=%s WARN=%s FAIL=%s\n' "$pass" "$warn" "$fail"
}

output_json(){
  local i
  printf '{"summary":{"pass":%s,"warn":%s,"fail":%s},"checks":[' "$pass" "$warn" "$fail"
  for i in "${!names[@]}"; do
    ((i>0)) && printf ','
    printf '{"name":"%s","status":"%s","detail":"%s"}' \
      "$(json_escape "${names[$i]}")" "$(json_escape "${stats[$i]}")" "$(json_escape "${details[$i]}")"
  done
  printf ']}\n'
}

strict=false
json=false
names=(); stats=(); details=()

while (($#)); do
  case "$1" in
    --strict) strict=true ;;
    --json) json=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

for c in kubectl helm; do
  if command_exists "$c"; then add "cmd:$c" PASS "found"; else add "cmd:$c" FAIL "missing"; fi
done

if [[ -f "$HOME/.kube/config" ]]; then
  add kube:config PASS "$HOME/.kube/config present"
else
  add kube:config WARN "$HOME/.kube/config missing"
fi

if command_exists kubectl; then
  ctx="$(kubectl config current-context 2> /dev/null || true)"
  if [[ -n "$ctx" ]]; then add kube:context PASS "$ctx"; else add kube:context WARN "no current context"; fi
fi

pass=0; warn=0; fail=0
for s in "${stats[@]}"; do
  case "$s" in PASS) pass=$((pass+1));; WARN) warn=$((warn+1));; FAIL) fail=$((fail+1));; esac
done

if $json; then output_json; else output_text; fi
((fail==0)) || exit 1
if $strict && ((warn>0)); then exit 1; fi
exit 0
