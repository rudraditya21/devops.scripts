#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: repo-healthcheck.sh [OPTIONS]

Assess repository hygiene and readiness for safe delivery workflows.

Options:
  --remote NAME          Remote name (default: origin)
  --default-branch NAME  Default branch override (default: remote HEAD)
  --max-file-mb N        Warn for tracked files above N MB (default: 10)
  --require-clean        Treat dirty worktree as FAIL
  --strict               Treat WARN as failure exit
  --json                 Emit JSON report
  -h, --help             Show help
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

remote="origin"
default_branch_override=""
max_file_mb=10
require_clean=false
strict_mode=false
json_mode=false
checks_name=()
checks_status=()
checks_detail=()

while (($#)); do
  case "$1" in
    --remote)
      shift
      (($#)) || die "--remote requires a value"
      remote="$1"
      ;;
    --default-branch)
      shift
      (($#)) || die "--default-branch requires a value"
      default_branch_override="$1"
      ;;
    --max-file-mb)
      shift
      (($#)) || die "--max-file-mb requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--max-file-mb must be a positive integer"
      max_file_mb="$1"
      ;;
    --require-clean)
      require_clean=true
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

if ! command_exists git; then
  die "git is required but not found"
fi

if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  add_check "repo:inside-worktree" "PASS" "inside git repository"
else
  add_check "repo:inside-worktree" "FAIL" "not inside git repository"
fi

if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  current_branch="$(git symbolic-ref --quiet --short HEAD 2> /dev/null || true)"
  if [[ -n "$current_branch" ]]; then
    add_check "repo:head" "PASS" "on branch $current_branch"
  else
    add_check "repo:head" "WARN" "detached HEAD"
  fi

  if git remote get-url "$remote" > /dev/null 2>&1; then
    add_check "remote:$remote" "PASS" "configured"
  else
    add_check "remote:$remote" "WARN" "not configured"
  fi

  if [[ -n "$default_branch_override" ]]; then
    default_branch="$default_branch_override"
  else
    default_head="$(git symbolic-ref --quiet --short "refs/remotes/$remote/HEAD" 2> /dev/null || true)"
    if [[ -n "$default_head" ]]; then
      default_branch="${default_head#"${remote}"/}"
    else
      default_branch="main"
    fi
  fi

  if git rev-parse --verify --quiet "$default_branch^{commit}" > /dev/null || git rev-parse --verify --quiet "$remote/$default_branch^{commit}" > /dev/null; then
    add_check "default-branch" "PASS" "$default_branch"
  else
    add_check "default-branch" "WARN" "default branch ref not found: $default_branch"
  fi

  if git diff --quiet && git diff --cached --quiet; then
    add_check "worktree:changes" "PASS" "no staged/unstaged changes"
  else
    if $require_clean; then
      add_check "worktree:changes" "FAIL" "repository has staged or unstaged changes"
    else
      add_check "worktree:changes" "WARN" "repository has staged or unstaged changes"
    fi
  fi

  untracked_count="$(git ls-files --others --exclude-standard | wc -l | awk '{print $1}')"
  if ((untracked_count == 0)); then
    add_check "worktree:untracked" "PASS" "no untracked files"
  else
    add_check "worktree:untracked" "WARN" "$untracked_count untracked file(s)"
  fi

  upstream_ref="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2> /dev/null || true)"
  if [[ -n "$upstream_ref" ]]; then
    read -r behind ahead <<< "$(git rev-list --left-right --count "${upstream_ref}...HEAD")"
    if ((behind > 0)); then
      add_check "upstream:sync" "WARN" "behind by $behind, ahead by $ahead"
    else
      add_check "upstream:sync" "PASS" "ahead by $ahead, not behind"
    fi
  else
    add_check "upstream:sync" "WARN" "no upstream configured"
  fi

  threshold_bytes=$((max_file_mb * 1024 * 1024))
  large_count=0
  largest_file=""
  largest_size=0

  while IFS= read -r tracked_file; do
    [[ -f "$tracked_file" ]] || continue
    file_size="$(wc -c < "$tracked_file" | awk '{print $1}')"
    if ((file_size > threshold_bytes)); then
      large_count=$((large_count + 1))
      if ((file_size > largest_size)); then
        largest_size=$file_size
        largest_file="$tracked_file"
      fi
    fi
  done < <(git ls-files)

  if ((large_count == 0)); then
    add_check "repo:large-files" "PASS" "no tracked files over ${max_file_mb}MB"
  else
    add_check "repo:large-files" "WARN" "$large_count file(s) over ${max_file_mb}MB; largest: $largest_file ($largest_size bytes)"
  fi

  if [[ -x .git/hooks/pre-push ]]; then
    add_check "hooks:pre-push" "PASS" "pre-push hook executable"
  else
    add_check "hooks:pre-push" "WARN" "pre-push hook missing or not executable"
  fi

  if [[ -f README.md ]]; then
    add_check "meta:README" "PASS" "README.md present"
  else
    add_check "meta:README" "WARN" "README.md missing"
  fi

  if [[ -f mkdocs.yml ]]; then
    add_check "meta:mkdocs" "PASS" "mkdocs.yml present"
  else
    add_check "meta:mkdocs" "WARN" "mkdocs.yml missing"
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

exit 0
