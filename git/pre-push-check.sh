#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: pre-push-check.sh [OPTIONS]

Run pre-push quality and history checks before pushing.

Options:
  --remote NAME         Remote to evaluate against (default: origin)
  --base REF            Base ref for commit range fallback (default: remote HEAD)
  --allow-behind        Do not fail if local branch is behind upstream
  --skip-format-check   Skip make format-check
  --skip-lint           Skip make lint
  --skip-docs-build     Skip make docs-build
  --skip-commit-msg     Skip commit message validation
  --custom-check CMD    Run additional shell command (repeatable)
  --strict              Fail on WARN checks
  --no-fetch            Skip fetch before checks
  --dry-run             Print actions without executing checks
  -h, --help            Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

require_git_repo() {
  command -v git > /dev/null 2>&1 || die "git is required but not found"
  git rev-parse --is-inside-work-tree > /dev/null 2>&1 || die "must run inside a git repository"
}

run_cmd() {
  if $dry_run; then
    printf 'DRY-RUN:' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
  else
    "$@"
  fi
}

add_check() {
  checks_name+=("$1")
  checks_status+=("$2")
  checks_detail+=("$3")
}

has_make_target() {
  local target="$1"
  make -qp 2> /dev/null | awk -F: -v target="$target" '$1 == target { found = 1 } END { exit(found ? 0 : 1) }'
}

run_make_target_check() {
  local target="$1"
  local name="$2"

  if [[ ! -f Makefile && ! -f makefile ]]; then
    add_check "$name" "WARN" "Makefile not found"
    return 0
  fi

  if ! has_make_target "$target"; then
    add_check "$name" "WARN" "make target '$target' not found"
    return 0
  fi

  if $dry_run; then
    add_check "$name" "PASS" "dry-run: make $target"
    return 0
  fi

  if make "$target" > /dev/null 2>&1; then
    add_check "$name" "PASS" "make $target passed"
  else
    add_check "$name" "FAIL" "make $target failed"
  fi
}

validate_commit_range_messages() {
  local range="$1"
  local validator="$2"
  local tmp_file
  local commit
  local status=0

  while IFS= read -r commit; do
    [[ -n "$commit" ]] || continue
    tmp_file="$(mktemp)"
    git log -1 --pretty=%B "$commit" > "$tmp_file"

    if ! "$validator" "$tmp_file" > /dev/null 2>&1; then
      status=1
      rm -f "$tmp_file"
      break
    fi

    rm -f "$tmp_file"
  done < <(git rev-list --reverse "$range")

  return "$status"
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

remote="origin"
base_ref=""
allow_behind=false
skip_format_check=false
skip_lint=false
skip_docs_build=false
skip_commit_msg=false
strict_mode=false
fetch_remote=true
dry_run=false
custom_checks=()
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
    --base)
      shift
      (($#)) || die "--base requires a value"
      base_ref="$1"
      ;;
    --allow-behind)
      allow_behind=true
      ;;
    --skip-format-check)
      skip_format_check=true
      ;;
    --skip-lint)
      skip_lint=true
      ;;
    --skip-docs-build)
      skip_docs_build=true
      ;;
    --skip-commit-msg)
      skip_commit_msg=true
      ;;
    --custom-check)
      shift
      (($#)) || die "--custom-check requires a value"
      custom_checks+=("$1")
      ;;
    --strict)
      strict_mode=true
      ;;
    --no-fetch)
      fetch_remote=false
      ;;
    --dry-run)
      dry_run=true
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

require_git_repo
git remote get-url "$remote" > /dev/null 2>&1 || die "remote does not exist: $remote"

current_branch="$(git symbolic-ref --quiet --short HEAD 2> /dev/null || true)"
[[ -n "$current_branch" ]] || die "detached HEAD is not supported"

if $fetch_remote; then
  run_cmd git fetch --prune "$remote"
fi

if [[ -z "$base_ref" ]]; then
  default_remote_head="$(git symbolic-ref --quiet --short "refs/remotes/$remote/HEAD" 2> /dev/null || true)"
  if [[ -n "$default_remote_head" ]]; then
    base_ref="$default_remote_head"
  else
    base_ref="$remote/main"
  fi
fi

if git rev-parse --verify --quiet "$base_ref^{commit}" > /dev/null; then
  add_check "base-ref" "PASS" "$base_ref"
else
  add_check "base-ref" "FAIL" "base reference not found: $base_ref"
fi

upstream_ref="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2> /dev/null || true)"
if [[ -n "$upstream_ref" ]]; then
  add_check "upstream" "PASS" "$upstream_ref"

  read -r behind ahead <<< "$(git rev-list --left-right --count "${upstream_ref}...HEAD")"
  if ((behind > 0)); then
    if $allow_behind; then
      add_check "ahead-behind" "WARN" "branch behind upstream by $behind commit(s), ahead by $ahead"
    else
      add_check "ahead-behind" "FAIL" "branch behind upstream by $behind commit(s)"
    fi
  else
    add_check "ahead-behind" "PASS" "ahead by $ahead commit(s), not behind"
  fi

  commit_range="${upstream_ref}..HEAD"
else
  add_check "upstream" "WARN" "no upstream configured for $current_branch"
  commit_range="${base_ref}..HEAD"
fi

if ! $skip_commit_msg; then
  validator_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/validate-commit-msg.sh"
  if [[ -x "$validator_script" ]]; then
    if $dry_run; then
      add_check "commit-msg" "PASS" "dry-run: validate commits in $commit_range"
    else
      commit_count="$(git rev-list --count "$commit_range" 2> /dev/null || true)"
      if [[ -z "$commit_count" || "$commit_count" == "0" ]]; then
        add_check "commit-msg" "PASS" "no outgoing commits to validate"
      elif validate_commit_range_messages "$commit_range" "$validator_script"; then
        add_check "commit-msg" "PASS" "validated $commit_count commit message(s)"
      else
        add_check "commit-msg" "FAIL" "one or more commit messages invalid in $commit_range"
      fi
    fi
  else
    add_check "commit-msg" "WARN" "validator script not executable: $validator_script"
  fi
fi

if ! $skip_format_check; then
  run_make_target_check "format-check" "format-check"
fi

if ! $skip_lint; then
  run_make_target_check "lint" "lint"
fi

if ! $skip_docs_build; then
  run_make_target_check "docs-build" "docs-build"
fi

if ((${#custom_checks[@]} > 0)); then
  i=1
  for cmd in "${custom_checks[@]}"; do
    if $dry_run; then
      add_check "custom-$i" "PASS" "dry-run: $cmd"
    else
      if bash -lc "$cmd" > /dev/null 2>&1; then
        add_check "custom-$i" "PASS" "$cmd"
      else
        add_check "custom-$i" "FAIL" "$cmd"
      fi
    fi
    i=$((i + 1))
  done
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

output_text

if ((fail_count > 0)); then
  exit 1
fi

if $strict_mode && ((warn_count > 0)); then
  exit 1
fi

exit 0
