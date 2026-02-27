#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: branch-delete.sh [OPTIONS]

Delete local and optional remote branch with protection rules.

Options:
  --name NAME         Branch name to delete (required)
  --force             Force-delete local branch (-D)
  --delete-remote     Also delete branch from remote
  --remote NAME       Remote name for remote delete (default: origin)
  --protect CSV       Additional protected branches (comma-separated)
  --yes               Required with --delete-remote
  --dry-run           Print actions without executing
  -h, --help          Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [branch-delete] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
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

branch_in_csv() {
  local branch="$1"
  local csv="$2"
  local item
  IFS=',' read -r -a items <<< "$csv"
  for item in "${items[@]}"; do
    [[ -n "$item" ]] || continue
    if [[ "$item" == "$branch" ]]; then
      return 0
    fi
  done
  return 1
}

validate_branch_name() {
  git check-ref-format --branch "$1" > /dev/null 2>&1 || die "invalid branch name: $1"
}

remote_branch_exists() {
  git ls-remote --exit-code --heads "$1" "$2" > /dev/null 2>&1
}

name=""
force_delete=false
delete_remote=false
remote="origin"
additional_protect=""
yes=false
dry_run=false

while (($#)); do
  case "$1" in
    --name)
      shift
      (($#)) || die "--name requires a value"
      name="$1"
      ;;
    --force)
      force_delete=true
      ;;
    --delete-remote)
      delete_remote=true
      ;;
    --remote)
      shift
      (($#)) || die "--remote requires a value"
      remote="$1"
      ;;
    --protect)
      shift
      (($#)) || die "--protect requires a value"
      additional_protect="$1"
      ;;
    --yes)
      yes=true
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

current_branch=""
current_branch="$(git symbolic-ref --quiet --short HEAD 2> /dev/null || true)"
[[ -n "$current_branch" ]] || die "detached HEAD is not supported for branch deletion"

protected_branches="main,master,develop,staging,production"
default_remote_head="$(git symbolic-ref --quiet --short "refs/remotes/$remote/HEAD" 2> /dev/null || true)"
if [[ -n "$default_remote_head" ]]; then
  default_remote_branch="${default_remote_head#"${remote}"/}"
  protected_branches+="${protected_branches:+,}${default_remote_branch}"
fi
if [[ -n "$additional_protect" ]]; then
  protected_branches+="${protected_branches:+,}${additional_protect}"
fi

if branch_in_csv "$name" "$protected_branches"; then
  die "refusing to delete protected branch: $name"
fi

if [[ "$name" == "$current_branch" ]]; then
  die "cannot delete currently checked out branch: $name"
fi

local_exists=false
if git show-ref --verify --quiet "refs/heads/$name"; then
  local_exists=true
fi

if ! $local_exists && ! $delete_remote; then
  die "branch '$name' does not exist locally"
fi

if $local_exists; then
  if $force_delete; then
    run_cmd git branch -D "$name"
  else
    run_cmd git branch -d "$name"
  fi
  log "deleted local branch '$name'"
fi

if $delete_remote; then
  $yes || die "--yes is required with --delete-remote"

  git remote get-url "$remote" > /dev/null 2>&1 || die "remote does not exist: $remote"

  if remote_branch_exists "$remote" "$name"; then
    run_cmd git push "$remote" --delete "$name"
    log "deleted remote branch '$remote/$name'"
  else
    log "remote branch '$remote/$name' not found; skipping"
  fi
fi

exit 0
