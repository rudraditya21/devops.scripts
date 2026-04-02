#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: healthcheck.sh [OPTIONS]

Run basic health checks for release git workflows.

Options:
  --strict             Treat WARN/SKIP as failure
  --json               Emit JSON output
  -h, --help           Show help
USAGE
}

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 2; }
json_escape(){ local s="${1-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }

strict=false
json=false

while (($#)); do
  case "$1" in
    --strict) strict=true ;;
    --json) json=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

cmd_status="PASS"
cmd_detail="git available"
if ! command -v git > /dev/null 2>&1; then
  cmd_status="FAIL"
  cmd_detail="git not found"
fi

repo_status="WARN"
repo_detail="not a git worktree"
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  repo_status="PASS"
  repo_detail="inside git worktree"
fi

overall="PASS"
if [[ "$cmd_status" == "FAIL" ]]; then
  overall="FAIL"
elif [[ "$strict" == true && "$repo_status" != "PASS" ]]; then
  overall="FAIL"
fi

if $json; then
  printf '{"domain":"release","overall":"%s","checks":[{"name":"cmd:git","status":"%s","detail":"%s"},{"name":"repo","status":"%s","detail":"%s"}]}' \
    "$(json_escape "$overall")" \
    "$(json_escape "$cmd_status")" \
    "$(json_escape "$cmd_detail")" \
    "$(json_escape "$repo_status")" \
    "$(json_escape "$repo_detail")"
  printf '\n'
else
  printf 'domain: release\n'
  printf 'overall: %s\n' "$overall"
  printf 'checks:\n'
  printf '  - cmd:git => %s (%s)\n' "$cmd_status" "$cmd_detail"
  printf '  - repo => %s (%s)\n' "$repo_status" "$repo_detail"
fi

[[ "$overall" == "PASS" ]] || exit 1
exit 0
