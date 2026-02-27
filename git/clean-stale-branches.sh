#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: clean-stale-branches.sh [OPTIONS]

Find and clean stale branches based on merge status and age.

Options:
  --base REF          Base reference for merge checks (default: remote HEAD)
  --remote NAME       Remote name (default: origin)
  --min-age-days N    Minimum age in days to consider stale (default: 30)
  --include-unmerged  Include branches not merged into base
  --delete-remote     Delete stale branches on remote (requires --apply --yes)
  --protect CSV       Additional protected branches (comma-separated)
  --apply             Execute deletions (default: dry-run preview)
  --yes               Required with --delete-remote when --apply is set
  --force-local       Force local delete for unmerged branches (-D)
  --no-fetch          Skip fetch --prune
  -h, --help          Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [clean-stale-branches] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

require_git_repo() {
  command -v git > /dev/null 2>&1 || die "git is required but not found"
  git rev-parse --is-inside-work-tree > /dev/null 2>&1 || die "must run inside a git repository"
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

is_merged_into_base() {
  local branch_ref="$1"
  local base_ref="$2"
  git merge-base --is-ancestor "$branch_ref" "$base_ref" > /dev/null 2>&1
}

base_ref=""
remote="origin"
min_age_days=30
include_unmerged=false
delete_remote=false
additional_protect=""
apply_changes=false
yes=false
force_local=false
fetch_remote=true

while (($#)); do
  case "$1" in
    --base)
      shift
      (($#)) || die "--base requires a value"
      base_ref="$1"
      ;;
    --remote)
      shift
      (($#)) || die "--remote requires a value"
      remote="$1"
      ;;
    --min-age-days)
      shift
      (($#)) || die "--min-age-days requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--min-age-days must be a positive integer"
      min_age_days="$1"
      ;;
    --include-unmerged)
      include_unmerged=true
      ;;
    --delete-remote)
      delete_remote=true
      ;;
    --protect)
      shift
      (($#)) || die "--protect requires a value"
      additional_protect="$1"
      ;;
    --apply)
      apply_changes=true
      ;;
    --yes)
      yes=true
      ;;
    --force-local)
      force_local=true
      ;;
    --no-fetch)
      fetch_remote=false
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

if $delete_remote && (! $apply_changes || ! $yes); then
  die "--delete-remote requires --apply --yes"
fi

if $fetch_remote; then
  git fetch --prune "$remote" > /dev/null 2>&1 || die "fetch failed for remote: $remote"
fi

if [[ -z "$base_ref" ]]; then
  remote_head="$(git symbolic-ref --quiet --short "refs/remotes/$remote/HEAD" 2> /dev/null || true)"
  if [[ -n "$remote_head" ]]; then
    base_ref="$remote_head"
  else
    base_ref="$remote/main"
  fi
fi

resolved_base="$(resolve_ref "$base_ref" "$remote" || true)"
[[ -n "$resolved_base" ]] || die "base reference not found: $base_ref"

current_branch="$(git symbolic-ref --quiet --short HEAD 2> /dev/null || true)"
[[ -n "$current_branch" ]] || die "detached HEAD is not supported"

protected="main,master,develop,staging,production"
protected+="${protected:+,}${current_branch}"
protected+="${protected:+,}${resolved_base#"${remote}"/}"
protected+="${protected:+,}${resolved_base}"
if [[ -n "$additional_protect" ]]; then
  protected+="${protected:+,}${additional_protect}"
fi

now_epoch="$(date +%s)"
cutoff_epoch=$((now_epoch - (min_age_days * 86400)))

local_candidates=()
remote_candidates=()

while read -r branch_name commit_ts; do
  [[ -n "$branch_name" ]] || continue
  [[ -n "$commit_ts" ]] || continue

  if branch_in_csv "$branch_name" "$protected"; then
    continue
  fi

  if ((commit_ts > cutoff_epoch)); then
    continue
  fi

  if ! $include_unmerged; then
    if ! is_merged_into_base "$branch_name" "$resolved_base"; then
      continue
    fi
  fi

  local_candidates+=("$branch_name")
done < <(git for-each-ref --format='%(refname:short) %(committerdate:unix)' refs/heads)

while read -r remote_ref commit_ts; do
  [[ -n "$remote_ref" ]] || continue
  [[ -n "$commit_ts" ]] || continue

  branch_name="${remote_ref#"${remote}"/}"
  [[ "$branch_name" == "HEAD" ]] && continue

  if branch_in_csv "$branch_name" "$protected" || branch_in_csv "$remote_ref" "$protected"; then
    continue
  fi

  if ((commit_ts > cutoff_epoch)); then
    continue
  fi

  if ! $include_unmerged; then
    if ! is_merged_into_base "$remote_ref" "$resolved_base"; then
      continue
    fi
  fi

  remote_candidates+=("$branch_name")
done < <(git for-each-ref --format='%(refname:short) %(committerdate:unix)' "refs/remotes/$remote")

printf 'Mode: %s\n' "$([ "$apply_changes" = true ] && printf 'apply' || printf 'dry-run')"
printf 'Base: %s\n' "$resolved_base"
printf 'Age threshold: %s days\n\n' "$min_age_days"

printf 'Local stale branches (%s):\n' "${#local_candidates[@]}"
for branch_name in "${local_candidates[@]}"; do
  printf '  - %s\n' "$branch_name"
done
[[ ${#local_candidates[@]} -gt 0 ]] || printf '  (none)\n'

printf '\nRemote stale branches (%s):\n' "${#remote_candidates[@]}"
for branch_name in "${remote_candidates[@]}"; do
  printf '  - %s/%s\n' "$remote" "$branch_name"
done
[[ ${#remote_candidates[@]} -gt 0 ]] || printf '  (none)\n'

if ! $apply_changes; then
  log "preview only; rerun with --apply to execute local deletions"
  if $delete_remote; then
    log "remote delete requested but preview mode active"
  fi
  exit 0
fi

failed=0

if ((${#local_candidates[@]} > 0)); then
  delete_flag="-d"
  if $include_unmerged && $force_local; then
    delete_flag="-D"
  fi

  for branch_name in "${local_candidates[@]}"; do
    if git branch "$delete_flag" "$branch_name" > /dev/null 2>&1; then
      log "deleted local branch '$branch_name'"
    else
      log "failed to delete local branch '$branch_name'"
      failed=$((failed + 1))
    fi
  done
fi

if $delete_remote && ((${#remote_candidates[@]} > 0)); then
  for branch_name in "${remote_candidates[@]}"; do
    if git push "$remote" --delete "$branch_name" > /dev/null 2>&1; then
      log "deleted remote branch '$remote/$branch_name'"
    else
      log "failed to delete remote branch '$remote/$branch_name'"
      failed=$((failed + 1))
    fi
  done
fi

if ((failed > 0)); then
  exit 1
fi

exit 0
