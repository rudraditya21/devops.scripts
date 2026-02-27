#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: squash-branch.sh [OPTIONS]

Squash all commits on a branch since merge-base with base into one commit.

Options:
  --base REF          Base reference used for squash range (required)
  --branch NAME       Branch to squash (default: current branch)
  --message TEXT      Squash commit message
  --message-file PATH Read squash message from file
  --push              Push rewritten branch with --force-with-lease
  --remote NAME       Remote for --push/--fetch (default: origin)
  --yes               Required with --push
  --no-fetch          Skip remote fetch
  --dry-run           Print actions without executing
  -h, --help          Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [squash-branch] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
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

resolve_ref() {
  local ref="$1"
  local remote_name="$2"
  if git rev-parse --verify --quiet "$ref^{commit}" > /dev/null; then
    printf '%s' "$ref"
    return 0
  fi
  if git rev-parse --verify --quiet "$remote_name/$ref^{commit}" > /dev/null; then
    printf '%s/%s' "$remote_name" "$ref"
    return 0
  fi
  return 1
}

is_worktree_clean() {
  git diff --quiet && git diff --cached --quiet
}

sanitize_ref_fragment() {
  printf '%s' "$1" | tr '/ ' '--'
}

base_ref=""
branch_name=""
message_text=""
message_file=""
push_branch=false
remote="origin"
yes=false
fetch_remote=true
dry_run=false

while (($#)); do
  case "$1" in
    --base)
      shift
      (($#)) || die "--base requires a value"
      base_ref="$1"
      ;;
    --branch)
      shift
      (($#)) || die "--branch requires a value"
      branch_name="$1"
      ;;
    --message)
      shift
      (($#)) || die "--message requires a value"
      message_text="$1"
      ;;
    --message-file)
      shift
      (($#)) || die "--message-file requires a value"
      message_file="$1"
      ;;
    --push)
      push_branch=true
      ;;
    --remote)
      shift
      (($#)) || die "--remote requires a value"
      remote="$1"
      ;;
    --yes)
      yes=true
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

[[ -n "$base_ref" ]] || die "--base is required"
if [[ -n "$message_text" && -n "$message_file" ]]; then
  die "--message and --message-file are mutually exclusive"
fi
if [[ -z "$message_text" && -z "$message_file" ]]; then
  die "either --message or --message-file is required"
fi
if [[ -n "$message_file" && ! -f "$message_file" ]]; then
  die "message file not found: $message_file"
fi

require_git_repo

if [[ -z "$branch_name" ]]; then
  branch_name="$(git symbolic-ref --quiet --short HEAD 2> /dev/null || true)"
fi
[[ -n "$branch_name" ]] || die "detached HEAD is not supported; use --branch"

git check-ref-format --branch "$branch_name" > /dev/null 2>&1 || die "invalid branch name: $branch_name"

if $fetch_remote; then
  git remote get-url "$remote" > /dev/null 2>&1 || die "remote does not exist: $remote"
  run_cmd git fetch --prune "$remote"
fi

resolved_base="$(resolve_ref "$base_ref" "$remote" || true)"
[[ -n "$resolved_base" ]] || die "base reference not found: $base_ref"

if [[ "$branch_name" == "$resolved_base" || "$branch_name" == "$base_ref" ]]; then
  die "branch and base cannot be the same"
fi

current_branch="$(git symbolic-ref --quiet --short HEAD 2> /dev/null || true)"
[[ -n "$current_branch" ]] || die "detached HEAD is not supported"
if [[ "$current_branch" != "$branch_name" ]]; then
  run_cmd git checkout "$branch_name"
fi

is_worktree_clean || die "working tree must be clean before squash"

merge_base="$(git merge-base "$branch_name" "$resolved_base" 2> /dev/null || true)"
[[ -n "$merge_base" ]] || die "unable to find merge-base for '$branch_name' and '$resolved_base'"

commit_count="$(git rev-list --count "${merge_base}..${branch_name}")"
if ((commit_count == 0)); then
  die "no commits to squash between '$merge_base' and '$branch_name'"
fi

timestamp="$(date +%Y%m%d%H%M%S)"
backup_branch="backup-squash-$(sanitize_ref_fragment "$branch_name")-$timestamp"
run_cmd git branch "$backup_branch" "$branch_name"
log "created backup branch '$backup_branch'"

run_cmd git reset --soft "$merge_base"
if [[ -n "$message_file" ]]; then
  run_cmd git commit --file "$message_file"
else
  run_cmd git commit --message "$message_text"
fi

log "squashed $commit_count commit(s) on '$branch_name'"

if $push_branch; then
  $yes || die "--yes is required with --push because history is rewritten"
  run_cmd git push --force-with-lease "$remote" "$branch_name:$branch_name"
  log "force-pushed '$branch_name' to '$remote'"
fi

exit 0
