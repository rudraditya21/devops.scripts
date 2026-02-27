#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: tag-release.sh [OPTIONS]

Create an annotated release tag with optional GPG signing and remote push.

Options:
  --tag NAME          Tag name (required, semver-like)
  --ref REF           Target ref (default: HEAD)
  --message TEXT      Annotated tag message (default: "Release <tag>")
  --message-file PATH Read tag message from file
  --sign              Create signed tag (-s)
  --force             Replace local tag if it exists
  --push              Push tag to remote
  --remote NAME       Remote for --push (default: origin)
  --dry-run           Print actions without executing
  -h, --help          Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [tag-release] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
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

validate_tag_name() {
  [[ "$1" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]] || die "tag must be semver-like (example: v1.2.3)"
  git check-ref-format "refs/tags/$1" > /dev/null 2>&1 || die "invalid tag name: $1"
}

tag_name=""
target_ref="HEAD"
message_text=""
message_file=""
sign_tag=false
force_tag=false
push_tag=false
remote="origin"
dry_run=false

while (($#)); do
  case "$1" in
    --tag)
      shift
      (($#)) || die "--tag requires a value"
      tag_name="$1"
      ;;
    --ref)
      shift
      (($#)) || die "--ref requires a value"
      target_ref="$1"
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
    --sign)
      sign_tag=true
      ;;
    --force)
      force_tag=true
      ;;
    --push)
      push_tag=true
      ;;
    --remote)
      shift
      (($#)) || die "--remote requires a value"
      remote="$1"
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

[[ -n "$tag_name" ]] || die "--tag is required"
if [[ -n "$message_text" && -n "$message_file" ]]; then
  die "--message and --message-file are mutually exclusive"
fi
if [[ -n "$message_file" && ! -f "$message_file" ]]; then
  die "message file not found: $message_file"
fi

require_git_repo
validate_tag_name "$tag_name"

git rev-parse --verify --quiet "$target_ref^{commit}" > /dev/null || die "target ref not found: $target_ref"

if git show-ref --verify --quiet "refs/tags/$tag_name"; then
  if $force_tag; then
    run_cmd git tag -d "$tag_name"
  else
    die "tag already exists: $tag_name (use --force to replace)"
  fi
fi

if $sign_tag; then
  command -v gpg > /dev/null 2>&1 || die "gpg is required for --sign"
fi

if [[ -z "$message_text" && -z "$message_file" ]]; then
  message_text="Release $tag_name"
fi

tag_cmd=(git tag -a)
$sign_tag && tag_cmd+=(-s)
$force_tag && tag_cmd+=(-f)
tag_cmd+=("$tag_name" "$target_ref")
if [[ -n "$message_file" ]]; then
  tag_cmd+=(--file "$message_file")
else
  tag_cmd+=(--message "$message_text")
fi

run_cmd "${tag_cmd[@]}"
log "created tag '$tag_name' at '$target_ref'"

if $push_tag; then
  git remote get-url "$remote" > /dev/null 2>&1 || die "remote does not exist: $remote"
  if $force_tag; then
    run_cmd git push "$remote" "refs/tags/$tag_name" --force
  else
    run_cmd git push "$remote" "refs/tags/$tag_name"
  fi
  log "pushed tag '$tag_name' to '$remote'"
fi

exit 0
