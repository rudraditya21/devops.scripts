#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: validate-commit-msg.sh [OPTIONS] COMMIT_MSG_FILE

Validate commit message against conventional commit requirements.

Options:
  --types CSV            Allowed types (default: feat,fix,docs,style,refactor,perf,test,build,ci,chore,revert)
  --max-subject N        Max subject length after prefix (default: 72)
  --max-body-line N      Max body/footer line length (default: 120)
  --allow-merge-commits  Allow "Merge ..." commits without conventional format
  -h, --help             Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log_error() {
  printf 'INVALID: %s\n' "$*" >&2
}

trim_cr() {
  local line="$1"
  line="${line%$'\r'}"
  printf '%s' "$line"
}

join_types_for_regex() {
  local csv="$1"
  local result=""
  local item
  IFS=',' read -r -a items <<< "$csv"
  for item in "${items[@]}"; do
    [[ -n "$item" ]] || continue
    if [[ -n "$result" ]]; then
      result+="|"
    fi
    result+="$item"
  done
  printf '%s' "$result"
}

allowed_types_csv="feat,fix,docs,style,refactor,perf,test,build,ci,chore,revert"
max_subject=72
max_body_line=120
allow_merge_commits=false

while (($#)); do
  case "$1" in
    --types)
      shift
      (($#)) || die "--types requires a value"
      allowed_types_csv="$1"
      ;;
    --max-subject)
      shift
      (($#)) || die "--max-subject requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--max-subject must be a positive integer"
      max_subject="$1"
      ;;
    --max-body-line)
      shift
      (($#)) || die "--max-body-line requires a value"
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--max-body-line must be a positive integer"
      max_body_line="$1"
      ;;
    --allow-merge-commits)
      allow_merge_commits=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      break
      ;;
  esac
  shift
done

(($# == 1)) || die "COMMIT_MSG_FILE is required"
commit_msg_file="$1"
[[ -f "$commit_msg_file" ]] || die "commit message file not found: $commit_msg_file"

header_raw="$(head -n 1 "$commit_msg_file" || true)"
header="$(trim_cr "$header_raw")"
[[ -n "$header" ]] || {
  log_error "commit header is empty"
  exit 1
}

if $allow_merge_commits && [[ "$header" =~ ^Merge[[:space:]] ]]; then
  exit 0
fi

types_regex="$(join_types_for_regex "$allowed_types_csv")"
[[ -n "$types_regex" ]] || die "--types cannot be empty"

if ! [[ "$header" =~ ^(${types_regex})(\([A-Za-z0-9._/-]+\))?(!)?:[[:space:]].+ ]]; then
  log_error "header must follow conventional commits (type(scope)!: subject)"
  log_error "allowed types: $allowed_types_csv"
  exit 1
fi

subject="${header#*: }"
subject_len=${#subject}
if ((subject_len > max_subject)); then
  log_error "subject too long (${subject_len} > ${max_subject})"
  exit 1
fi

if [[ "$subject" =~ [[:space:]]$ ]]; then
  log_error "subject must not end with trailing whitespace"
  exit 1
fi

if [[ "$subject" =~ \.$ ]]; then
  log_error "subject should not end with a period"
  exit 1
fi

if [[ "$subject" =~ ^[A-Z] ]]; then
  log_error "subject should start with lowercase imperative verb"
  exit 1
fi

line_number=0
second_line=""
has_more_than_one_line=false
while IFS= read -r line || [[ -n "$line" ]]; do
  line_number=$((line_number + 1))
  line="$(trim_cr "$line")"

  if ((line_number == 2)); then
    second_line="$line"
  fi

  if ((line_number > 1)); then
    has_more_than_one_line=true
  fi

done < "$commit_msg_file"

if $has_more_than_one_line && [[ -n "$second_line" ]]; then
  log_error "line 2 must be blank between header and body/footer"
  exit 1
fi

line_number=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line_number=$((line_number + 1))
  line="$(trim_cr "$line")"

  if ((line_number <= 2)); then
    continue
  fi

  if [[ -n "$line" ]]; then
    if ((${#line} > max_body_line)); then
      log_error "line ${line_number} exceeds max length (${max_body_line})"
      exit 1
    fi
  fi
done < "$commit_msg_file"

exit 0
