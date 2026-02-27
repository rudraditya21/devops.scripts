#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: rebase-safe.sh [OPTIONS]

Safely rebase a branch onto a target reference with backup creation.

Options:
  --onto REF         Rebase target reference (required)
  --branch NAME      Branch to rebase (default: current branch)
  --remote NAME      Remote for fetch/target fallback (default: origin)
  --no-fetch         Skip remote fetch
  --autostash        Use git rebase --autostash
  --rebase-merges    Preserve merge commits during rebase
  --autosquash       Enable autosquash for fixup!/squash! commits
  --dry-run          Print actions without executing
  -h, --help         Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [rebase-safe] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
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

is_worktree_clean() {
  git diff --quiet && git diff --cached --quiet
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

sanitize_ref_fragment() {
  printf '%s' "$1" | tr '/ ' '--'
}

onto_ref=""
branch_name=""
remote="origin"
fetch_remote=true
autostash=false
rebase_merges=false
autosquash=false
dry_run=false

while (($#)); do
  case "$1" in
    --onto)
      shift
      (($#)) || die "--onto requires a value"
      onto_ref="$1"
      ;;
    --branch)
      shift
      (($#)) || die "--branch requires a value"
      branch_name="$1"
      ;;
    --remote)
      shift
      (($#)) || die "--remote requires a value"
      remote="$1"
      ;;
    --no-fetch)
      fetch_remote=false
      ;;
    --autostash)
      autostash=true
      ;;
    --rebase-merges)
      rebase_merges=true
      ;;
    --autosquash)
      autosquash=true
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

[[ -n "$onto_ref" ]] || die "--onto is required"

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

resolved_onto="$(resolve_ref "$onto_ref" "$remote" || true)"
[[ -n "$resolved_onto" ]] || die "rebase target not found: $onto_ref"

current_branch="$(git symbolic-ref --quiet --short HEAD 2> /dev/null || true)"
[[ -n "$current_branch" ]] || die "detached HEAD is not supported"
if [[ "$current_branch" != "$branch_name" ]]; then
  run_cmd git checkout "$branch_name"
fi

if ! $autostash && ! is_worktree_clean; then
  die "working tree is not clean; commit/stash changes or use --autostash"
fi

timestamp="$(date +%Y%m%d%H%M%S)"
backup_branch="backup-$(sanitize_ref_fragment "$branch_name")-$timestamp"
run_cmd git branch "$backup_branch" "$branch_name"
log "created backup branch '$backup_branch'"

rebase_cmd=(git rebase)
$autostash && rebase_cmd+=(--autostash)
$rebase_merges && rebase_cmd+=(--rebase-merges)
$autosquash && rebase_cmd+=(--autosquash)
rebase_cmd+=("$resolved_onto")

if $dry_run; then
  run_cmd "${rebase_cmd[@]}"
  exit 0
fi

set +e
"${rebase_cmd[@]}"
rebase_status=$?
set -e

if ((rebase_status != 0)); then
  log "rebase failed; recovery options:"
  log "1) git rebase --abort"
  log "2) git reset --hard $backup_branch"
  exit "$rebase_status"
fi

log "rebase completed successfully onto '$resolved_onto'"
log "backup branch retained at '$backup_branch'"
exit 0
