#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: branch-create.sh [OPTIONS]

Create a new branch from a base reference with optional checkout and upstream push.

Options:
  --name NAME        Branch name to create (required)
  --from REF         Base reference (default: HEAD)
  --checkout         Checkout created branch (default)
  --no-checkout      Do not checkout after creation
  --push             Push branch to remote and set upstream
  --remote NAME      Remote for --push/--fetch (default: origin)
  --no-fetch         Skip remote fetch before branch creation
  --dry-run          Print actions without executing
  -h, --help         Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [branch-create] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

require_git_repo() {
  command -v git > /dev/null 2>&1 || die "git is required but not found"
  git rev-parse --is-inside-work-tree > /dev/null 2>&1 || die "must run inside a git repository"
}

ref_exists() {
  git rev-parse --verify --quiet "$1^{commit}" > /dev/null
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

validate_branch_name() {
  git check-ref-format --branch "$1" > /dev/null 2>&1 || die "invalid branch name: $1"
}

ensure_remote_exists() {
  git remote get-url "$1" > /dev/null 2>&1 || die "remote does not exist: $1"
}

name=""
from_ref="HEAD"
checkout_branch=true
push_branch=false
remote="origin"
fetch_remote=true
dry_run=false

while (($#)); do
  case "$1" in
    --name)
      shift
      (($#)) || die "--name requires a value"
      name="$1"
      ;;
    --from)
      shift
      (($#)) || die "--from requires a value"
      from_ref="$1"
      ;;
    --checkout)
      checkout_branch=true
      ;;
    --no-checkout)
      checkout_branch=false
      ;;
    --push)
      push_branch=true
      ;;
    --remote)
      shift
      (($#)) || die "--remote requires a value"
      remote="$1"
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

[[ -n "$name" ]] || die "--name is required"

require_git_repo
validate_branch_name "$name"

if $fetch_remote; then
  ensure_remote_exists "$remote"
  run_cmd git fetch --prune "$remote"
fi

if git show-ref --verify --quiet "refs/heads/$name"; then
  die "local branch already exists: $name"
fi

if ref_exists "$from_ref"; then
  resolved_from="$from_ref"
elif ref_exists "$remote/$from_ref"; then
  resolved_from="$remote/$from_ref"
else
  die "base reference not found: $from_ref"
fi

run_cmd git branch "$name" "$resolved_from"
log "created branch '$name' from '$resolved_from'"

if $checkout_branch; then
  run_cmd git checkout "$name"
  log "checked out '$name'"
fi

if $push_branch; then
  ensure_remote_exists "$remote"
  run_cmd git push --set-upstream "$remote" "$name:$name"
  log "pushed '$name' to '$remote' with upstream"
fi

exit 0
