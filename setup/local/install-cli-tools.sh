#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: install-cli-tools.sh [OPTIONS]

Install required CLI tools using an OS package manager.

Options:
  --tools CSV         Comma-separated tool list
  --tool NAME         Add one tool (repeatable)
  --manager NAME      auto|brew|apt|dnf|yum (default: auto)
  --yes               Non-interactive install mode
  --dry-run           Print commands without executing
  --update-cache      Force package metadata refresh
  -h, --help          Show help

Default tools (if none provided):
  git,curl,jq,yq,shellcheck,shfmt,kubectl,terraform,gh,gpg
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [install-cli-tools] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

run_cmd() {
  if $dry_run; then
    printf 'DRY-RUN: %s\n' "$*" >&2
    return 0
  fi
  "$@"
}

as_root() {
  if [[ "$(id -u)" == "0" ]]; then
    run_cmd "$@"
  else
    run_cmd sudo "$@"
  fi
}

normalize_tools() {
  local raw="$1"
  local item
  IFS=',' read -r -a _items <<< "$raw"
  for item in "${_items[@]}"; do
    item="$(printf '%s' "$item" | awk '{$1=$1; print}')"
    [[ -n "$item" ]] || continue
    tools+=("$item")
  done
}

detect_manager() {
  case "$manager" in
    auto)
      if command_exists brew; then
        manager="brew"
      elif command_exists apt-get; then
        manager="apt"
      elif command_exists dnf; then
        manager="dnf"
      elif command_exists yum; then
        manager="yum"
      else
        die "no supported package manager found (brew/apt/dnf/yum)"
      fi
      ;;
    brew | apt | dnf | yum) ;;
    *)
      die "unsupported manager: $manager"
      ;;
  esac
}

package_for_tool() {
  local tool="$1"
  local pm="$2"

  case "$pm" in
    brew)
      case "$tool" in
        git | curl | jq | yq | shellcheck | shfmt | kubectl | terraform | gh) printf '%s' "$tool" ;;
        gpg) printf 'gnupg' ;;
        *) return 1 ;;
      esac
      ;;
    apt)
      case "$tool" in
        git | curl | jq) printf '%s' "$tool" ;;
        yq) printf 'yq' ;;
        shellcheck | shfmt | kubectl | terraform | gh) printf '%s' "$tool" ;;
        gpg) printf 'gnupg' ;;
        *) return 1 ;;
      esac
      ;;
    dnf | yum)
      case "$tool" in
        git | curl | jq | yq | shellcheck | kubectl | terraform | gh) printf '%s' "$tool" ;;
        shfmt) printf 'shfmt' ;;
        gpg) printf 'gnupg2' ;;
        *) return 1 ;;
      esac
      ;;
    *)
      return 1
      ;;
  esac
}

install_package() {
  local pkg="$1"

  case "$manager" in
    brew)
      run_cmd brew install "$pkg"
      ;;
    apt)
      local apt_args=(-y)
      if ! $assume_yes; then
        apt_args=()
      fi
      as_root apt-get install "${apt_args[@]}" "$pkg"
      ;;
    dnf)
      local dnf_args=(-y)
      if ! $assume_yes; then
        dnf_args=()
      fi
      as_root dnf install "${dnf_args[@]}" "$pkg"
      ;;
    yum)
      local yum_args=(-y)
      if ! $assume_yes; then
        yum_args=()
      fi
      as_root yum install "${yum_args[@]}" "$pkg"
      ;;
    *)
      die "internal error: unsupported manager $manager"
      ;;
  esac
}

update_cache_if_needed() {
  if ! $update_cache; then
    return
  fi

  case "$manager" in
    apt)
      as_root apt-get update
      ;;
    dnf)
      as_root dnf makecache
      ;;
    yum)
      as_root yum makecache
      ;;
    brew)
      run_cmd brew update
      ;;
  esac
}

tools=()
manager="auto"
assume_yes=false
dry_run=false
update_cache=false

while (($#)); do
  case "$1" in
    --tools)
      shift
      (($#)) || die "--tools requires a value"
      normalize_tools "$1"
      ;;
    --tool)
      shift
      (($#)) || die "--tool requires a value"
      tools+=("$1")
      ;;
    --manager)
      shift
      (($#)) || die "--manager requires a value"
      manager="$1"
      ;;
    --yes)
      assume_yes=true
      ;;
    --dry-run)
      dry_run=true
      ;;
    --update-cache)
      update_cache=true
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

if ((${#tools[@]} == 0)); then
  normalize_tools 'git,curl,jq,yq,shellcheck,shfmt,kubectl,terraform,gh,gpg'
fi

detect_manager
log "using package manager: $manager"

update_cache_if_needed

failed_tools=()
for tool in "${tools[@]}"; do
  if command_exists "$tool"; then
    log "already installed: $tool"
    continue
  fi

  pkg=""
  if ! pkg="$(package_for_tool "$tool" "$manager")"; then
    log "unsupported tool for manager $manager: $tool"
    failed_tools+=("$tool")
    continue
  fi

  log "installing tool $tool (package: $pkg)"
  if ! install_package "$pkg"; then
    log "failed to install: $tool"
    failed_tools+=("$tool")
    continue
  fi

done

if ((${#failed_tools[@]} > 0)); then
  printf 'ERROR: failed or unsupported tools: %s\n' "${failed_tools[*]}" >&2
  exit 1
fi

log "all requested tools are installed"
