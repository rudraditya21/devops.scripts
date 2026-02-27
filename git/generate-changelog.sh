#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: generate-changelog.sh [OPTIONS]

Generate changelog entries from git commits in a range.

Options:
  --from REF          Start ref (default: auto-detect previous tag)
  --to REF            End ref (default: HEAD)
  --format FORMAT     Output format: markdown|plain (default: markdown)
  --output PATH       Write changelog to file (default: stdout)
  --include-merges    Include merge commits
  --max-commits N     Maximum commits to include (default: 500)
  --title TEXT        Changelog title (default: Changelog)
  -h, --help          Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [generate-changelog] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

require_git_repo() {
  command -v git > /dev/null 2>&1 || die "git is required but not found"
  git rev-parse --is-inside-work-tree > /dev/null 2>&1 || die "must run inside a git repository"
}

append_line() {
  local var_name="$1"
  local line="$2"
  local current="${!var_name-}"
  if [[ -n "$current" ]]; then
    printf -v "$var_name" '%s\n%s' "$current" "$line"
  else
    printf -v "$var_name" '%s' "$line"
  fi
}

classify_subject() {
  local subject="$1"
  case "$subject" in
    feat*": "*) printf 'features' ;;
    fix*": "*) printf 'fixes' ;;
    perf*": "*) printf 'performance' ;;
    refactor*": "*) printf 'refactors' ;;
    docs*": "*) printf 'docs' ;;
    build*": "* | ci*": "* | test*": "* | style*": "* | chore*": "* | revert*": "*) printf 'ops' ;;
    *) printf 'others' ;;
  esac
}

render_section_markdown() {
  local title="$1"
  local content="$2"
  [[ -n "$content" ]] || return 0
  printf '## %s\n\n' "$title"
  printf '%s\n\n' "$content"
}

render_section_plain() {
  local title="$1"
  local content="$2"
  [[ -n "$content" ]] || return 0
  printf '%s\n' "$title"
  printf '%s\n' "$(printf '%*s' "${#title}" '' | tr ' ' '-')"
  printf '%s\n\n' "$content"
}

auto_from_ref() {
  local to_ref="$1"
  local latest_tag
  latest_tag="$(git describe --tags --abbrev=0 "$to_ref" 2> /dev/null || true)"
  if [[ -z "$latest_tag" ]]; then
    printf ''
    return 0
  fi

  latest_tag_commit="$(git rev-list -n 1 "$latest_tag")"
  to_commit="$(git rev-list -n 1 "$to_ref")"

  if [[ "$latest_tag_commit" == "$to_commit" ]]; then
    git tag --merged "$to_ref" --sort=-creatordate | sed -n '2p'
  else
    printf '%s' "$latest_tag"
  fi
}

from_ref=""
to_ref="HEAD"
output_format="markdown"
output_path=""
include_merges=false
max_commits=500
title="Changelog"

while (($#)); do
  case "$1" in
    --from)
      shift
      (($#)) || die "--from requires a value"
      from_ref="$1"
      ;;
    --to)
      shift
      (($#)) || die "--to requires a value"
      to_ref="$1"
      ;;
    --format)
      shift
      (($#)) || die "--format requires a value"
      case "$1" in
        markdown | plain) output_format="$1" ;;
        *) die "invalid format: $1 (expected markdown or plain)" ;;
      esac
      ;;
    --output)
      shift
      (($#)) || die "--output requires a value"
      output_path="$1"
      ;;
    --include-merges)
      include_merges=true
      ;;
    --max-commits)
      shift
      (($#)) || die "--max-commits requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--max-commits must be a positive integer"
      max_commits="$1"
      ;;
    --title)
      shift
      (($#)) || die "--title requires a value"
      title="$1"
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

git rev-parse --verify --quiet "$to_ref^{commit}" > /dev/null || die "end ref not found: $to_ref"

if [[ -z "$from_ref" ]]; then
  from_ref="$(auto_from_ref "$to_ref")"
fi

range_spec="$to_ref"
range_label="start..$to_ref"
if [[ -n "$from_ref" ]]; then
  git rev-parse --verify --quiet "$from_ref^{commit}" > /dev/null || die "start ref not found: $from_ref"
  range_spec="${from_ref}..${to_ref}"
  range_label="$range_spec"
fi

log_cmd=(git log "--pretty=format:%H%x1f%s%x1f%an%x1f%ad%x1e" --date=short "--max-count=$max_commits")
$include_merges || log_cmd+=(--no-merges)
log_cmd+=("$range_spec")

features=""
fixes=""
performance=""
refactors=""
docs_changes=""
ops=""
others=""
commit_total=0

while IFS=$'\x1f' read -r -d $'\x1e' commit_hash subject author date_value; do
  [[ -n "$commit_hash" ]] || continue
  short_hash="${commit_hash:0:7}"
  if [[ "$output_format" == "markdown" ]]; then
    line="- ${subject} (\`${short_hash}\`, ${author}, ${date_value})"
  else
    line="- ${subject} (${short_hash}, ${author}, ${date_value})"
  fi

  category="$(classify_subject "$subject")"
  case "$category" in
    features) append_line features "$line" ;;
    fixes) append_line fixes "$line" ;;
    performance) append_line performance "$line" ;;
    refactors) append_line refactors "$line" ;;
    docs) append_line docs_changes "$line" ;;
    ops) append_line ops "$line" ;;
    *) append_line others "$line" ;;
  esac

  commit_total=$((commit_total + 1))
done < <("${log_cmd[@]}")

if [[ "$output_format" == "markdown" ]]; then
  output_content="# ${title}\n\n"
  output_content+="Range: \`${range_label}\`\n\n"
  if ((commit_total == 0)); then
    output_content+="No changes found for this range.\n"
  else
    section="$(render_section_markdown "Features" "$features")"
    output_content+="$section"
    section="$(render_section_markdown "Fixes" "$fixes")"
    output_content+="$section"
    section="$(render_section_markdown "Performance" "$performance")"
    output_content+="$section"
    section="$(render_section_markdown "Refactors" "$refactors")"
    output_content+="$section"
    section="$(render_section_markdown "Docs" "$docs_changes")"
    output_content+="$section"
    section="$(render_section_markdown "Build / CI / Chore" "$ops")"
    output_content+="$section"
    section="$(render_section_markdown "Other Changes" "$others")"
    output_content+="$section"
  fi
else
  output_content="${title}\n"
  output_content+="$(printf '%*s' "${#title}" '' | tr ' ' '=')\n\n"
  output_content+="Range: ${range_label}\n\n"
  if ((commit_total == 0)); then
    output_content+="No changes found for this range.\n"
  else
    section="$(render_section_plain "Features" "$features")"
    output_content+="$section"
    section="$(render_section_plain "Fixes" "$fixes")"
    output_content+="$section"
    section="$(render_section_plain "Performance" "$performance")"
    output_content+="$section"
    section="$(render_section_plain "Refactors" "$refactors")"
    output_content+="$section"
    section="$(render_section_plain "Docs" "$docs_changes")"
    output_content+="$section"
    section="$(render_section_plain "Build / CI / Chore" "$ops")"
    output_content+="$section"
    section="$(render_section_plain "Other Changes" "$others")"
    output_content+="$section"
  fi
fi

if [[ -n "$output_path" ]]; then
  printf '%b' "$output_content" > "$output_path"
  log "wrote changelog to '$output_path'"
else
  printf '%b' "$output_content"
fi

exit 0
