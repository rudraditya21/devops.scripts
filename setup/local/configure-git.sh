#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: configure-git.sh [OPTIONS]

Configure global git settings for workstation consistency.

Options:
  --name VALUE            Set user.name
  --email VALUE           Set user.email
  --default-branch NAME   Set init.defaultBranch (default: main)
  --editor VALUE          Set core.editor
  --credential-helper V   Set credential.helper (default: platform auto)
  --rebase-pull BOOL      Set pull.rebase true/false (default: false)
  --signing-key KEYID     Set user.signingkey
  --gpg-sign BOOL         Set commit.gpgsign true/false
  --dry-run               Print planned git config actions
  -h, --help              Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [configure-git] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

run_git_config() {
  local key="$1"
  local value="$2"
  if $dry_run; then
    printf 'DRY-RUN: git config --global %s %q\n' "$key" "$value" >&2
  else
    git config --global "$key" "$value"
  fi
}

ensure_git() {
  command -v git > /dev/null 2>&1 || die "git is required but not found"
}

normalize_bool() {
  case "$1" in
    true | false) printf '%s' "$1" ;;
    1 | yes | on) printf 'true' ;;
    0 | no | off) printf 'false' ;;
    *) die "invalid boolean value: $1 (use true/false)" ;;
  esac
}

auto_credential_helper() {
  case "$(uname -s)" in
    Darwin) printf 'osxkeychain' ;;
    Linux) printf 'cache --timeout=3600' ;;
    *) printf 'cache --timeout=3600' ;;
  esac
}

name_value=""
email_value=""
default_branch="main"
editor_value=""
credential_helper="$(auto_credential_helper)"
rebase_pull="false"
signing_key=""
gpg_sign=""
dry_run=false

while (($#)); do
  case "$1" in
    --name)
      shift
      (($#)) || die "--name requires a value"
      name_value="$1"
      ;;
    --email)
      shift
      (($#)) || die "--email requires a value"
      email_value="$1"
      ;;
    --default-branch)
      shift
      (($#)) || die "--default-branch requires a value"
      default_branch="$1"
      ;;
    --editor)
      shift
      (($#)) || die "--editor requires a value"
      editor_value="$1"
      ;;
    --credential-helper)
      shift
      (($#)) || die "--credential-helper requires a value"
      credential_helper="$1"
      ;;
    --rebase-pull)
      shift
      (($#)) || die "--rebase-pull requires a value"
      rebase_pull="$(normalize_bool "$1")"
      ;;
    --signing-key)
      shift
      (($#)) || die "--signing-key requires a value"
      signing_key="$1"
      ;;
    --gpg-sign)
      shift
      (($#)) || die "--gpg-sign requires a value"
      gpg_sign="$(normalize_bool "$1")"
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

ensure_git

run_git_config init.defaultBranch "$default_branch"
run_git_config pull.rebase "$rebase_pull"
run_git_config credential.helper "$credential_helper"

if [[ -n "$name_value" ]]; then
  run_git_config user.name "$name_value"
fi

if [[ -n "$email_value" ]]; then
  run_git_config user.email "$email_value"
fi

if [[ -n "$editor_value" ]]; then
  run_git_config core.editor "$editor_value"
fi

if [[ -n "$signing_key" ]]; then
  run_git_config user.signingkey "$signing_key"
  if [[ -z "$gpg_sign" ]]; then
    gpg_sign="true"
  fi
fi

if [[ -n "$gpg_sign" ]]; then
  run_git_config commit.gpgsign "$gpg_sign"
fi

log "git configuration applied"
