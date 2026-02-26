#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: setup-shell.sh [OPTIONS]

Apply managed shell configuration block to a target rc file.

Options:
  --shell NAME         auto|bash|zsh (default: auto)
  --rc-file PATH       Explicit rc file path (overrides --shell)
  --prepend-path PATH  Add a path prepend statement (repeatable)
  --set-editor VALUE   Export EDITOR and VISUAL
  --set-pager VALUE    Export PAGER
  --dry-run            Print planned change without writing
  -h, --help           Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [setup-shell] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

detect_shell() {
  if [[ -n "${SHELL:-}" ]]; then
    case "$(basename "$SHELL")" in
      zsh)
        printf 'zsh'
        return
        ;;
      bash)
        printf 'bash'
        return
        ;;
    esac
  fi
  printf 'bash'
}

resolve_rc_file() {
  if [[ -n "$rc_file" ]]; then
    printf '%s' "$rc_file"
    return
  fi

  case "$shell_name" in
    auto)
      shell_name="$(detect_shell)"
      ;;
    bash | zsh) ;;
    *)
      die "invalid --shell value: $shell_name"
      ;;
  esac

  case "$shell_name" in
    bash) printf '%s/.bashrc' "$HOME" ;;
    zsh) printf '%s/.zshrc' "$HOME" ;;
    *) die "unsupported shell: $shell_name" ;;
  esac
}

build_managed_block() {
  printf '%s\n' "# >>> devops.scripts managed shell setup >>>"
  printf '%s\n' "# This block is managed by setup-shell.sh."

  local p
  for p in "${prepend_paths[@]}"; do
    printf '%s\n' "if [ -d \"$p\" ] && [[ \":\$PATH:\" != *\":$p:\"* ]]; then export PATH=\"$p:\$PATH\"; fi"
  done

  if [[ -n "$editor_value" ]]; then
    printf '%s\n' "export EDITOR=\"$editor_value\""
    printf '%s\n' "export VISUAL=\"$editor_value\""
  fi

  if [[ -n "$pager_value" ]]; then
    printf '%s\n' "export PAGER=\"$pager_value\""
  fi

  printf '%s\n' "# <<< devops.scripts managed shell setup <<<"
}

merge_block() {
  local file="$1"
  local block_file="$2"
  local tmp_file="$3"

  awk '
    BEGIN { in_block=0 }
    /^# >>> devops\.scripts managed shell setup >>>$/ { in_block=1; next }
    /^# <<< devops\.scripts managed shell setup <<<$/ { in_block=0; next }
    in_block==0 { print }
  ' "$file" > "$tmp_file"

  if [[ -s "$tmp_file" ]]; then
    printf '\n' >> "$tmp_file"
  fi
  cat "$block_file" >> "$tmp_file"
}

shell_name="auto"
rc_file=""
prepend_paths=("$HOME/.local/bin")
editor_value=""
pager_value=""
dry_run=false
source_rc_file=""
source_rc_temp=""

while (($#)); do
  case "$1" in
    --shell)
      shift
      (($#)) || die "--shell requires a value"
      shell_name="$1"
      ;;
    --rc-file)
      shift
      (($#)) || die "--rc-file requires a value"
      rc_file="$1"
      ;;
    --prepend-path)
      shift
      (($#)) || die "--prepend-path requires a value"
      prepend_paths+=("$1")
      ;;
    --set-editor)
      shift
      (($#)) || die "--set-editor requires a value"
      editor_value="$1"
      ;;
    --set-pager)
      shift
      (($#)) || die "--set-pager requires a value"
      pager_value="$1"
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

target_rc="$(resolve_rc_file)"
if [[ -f "$target_rc" ]]; then
  source_rc_file="$target_rc"
else
  if $dry_run; then
    source_rc_file="$(mktemp "${TMPDIR:-/tmp}/setup-shell-source.XXXXXX")"
    source_rc_temp="$source_rc_file"
  else
    mkdir -p "$(dirname "$target_rc")"
    : > "$target_rc"
    source_rc_file="$target_rc"
  fi
fi

block_file="$(mktemp "${TMPDIR:-/tmp}/setup-shell-block.XXXXXX")"
tmp_file="$(mktemp "${TMPDIR:-/tmp}/setup-shell-merged.XXXXXX")"
trap 'rm -f "$block_file" "$tmp_file" "${source_rc_temp:-}"' EXIT

build_managed_block > "$block_file"
merge_block "$source_rc_file" "$block_file" "$tmp_file"

if $dry_run; then
  log "dry-run enabled; updated content for $target_rc"
  cat "$tmp_file"
  exit 0
fi

cp "$tmp_file" "$target_rc"
log "applied managed shell configuration to $target_rc"
