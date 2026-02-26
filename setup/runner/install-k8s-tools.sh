#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: install-k8s-tools.sh [OPTIONS]

Install Kubernetes ecosystem CLI tools.

Options:
  --tools CSV         Comma-separated tool list
  --tool NAME         Add one tool (repeatable)
  --manager NAME      auto|brew|apt|dnf|yum (default: auto)
  --yes               Non-interactive install mode
  --update-cache      Refresh package metadata before install
  --dry-run           Print commands without executing
  -h, --help          Show help

Supported tools:
  kubectl,helm,kustomize,kind
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [install-k8s-tools] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
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
  IFS=',' read -r -a parsed <<< "$raw"
  for item in "${parsed[@]}"; do
    item="$(printf '%s' "$item" | awk '{$1=$1; print}')"
    [[ -n "$item" ]] || continue
    tools+=("$item")
  done
}

tool_command() {
  case "$1" in
    kubectl | helm | kustomize | kind) printf '%s' "$1" ;;
    *) return 1 ;;
  esac
}

package_for_tool() {
  local tool="$1"
  local pm="$2"

  case "$pm" in
    brew)
      case "$tool" in
        kubectl | helm | kustomize | kind) printf '%s' "$tool" ;;
        *) return 1 ;;
      esac
      ;;
    apt)
      case "$tool" in
        kubectl | helm | kustomize | kind) printf '%s' "$tool" ;;
        *) return 1 ;;
      esac
      ;;
    dnf | yum)
      case "$tool" in
        kubectl | helm | kustomize | kind) printf '%s' "$tool" ;;
        *) return 1 ;;
      esac
      ;;
    *)
      return 1
      ;;
  esac
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
        die "no supported package manager found"
      fi
      ;;
    brew | apt | dnf | yum) ;;
    *)
      die "unsupported manager: $manager"
      ;;
  esac
}

update_cache_if_needed() {
  if ! $update_cache; then
    return
  fi

  case "$manager" in
    brew) run_cmd brew update ;;
    apt) as_root apt-get update ;;
    dnf) as_root dnf makecache ;;
    yum) as_root yum makecache ;;
  esac
}

install_package() {
  local pkg="$1"
  case "$manager" in
    brew)
      run_cmd brew install "$pkg"
      ;;
    apt)
      if $assume_yes; then
        as_root apt-get install -y "$pkg"
      else
        as_root apt-get install "$pkg"
      fi
      ;;
    dnf)
      if $assume_yes; then
        as_root dnf install -y "$pkg"
      else
        as_root dnf install "$pkg"
      fi
      ;;
    yum)
      if $assume_yes; then
        as_root yum install -y "$pkg"
      else
        as_root yum install "$pkg"
      fi
      ;;
  esac
}

tools=()
manager="auto"
assume_yes=false
update_cache=false
dry_run=false

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
    --update-cache)
      update_cache=true
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

if ((${#tools[@]} == 0)); then
  normalize_tools 'kubectl,helm,kustomize,kind'
fi

detect_manager
update_cache_if_needed

failed=()
for tool in "${tools[@]}"; do
  cmd=""
  if ! cmd="$(tool_command "$tool")"; then
    log "unsupported tool requested: $tool"
    failed+=("$tool")
    continue
  fi

  if command_exists "$cmd"; then
    log "already installed: $tool"
    continue
  fi

  pkg=""
  if ! pkg="$(package_for_tool "$tool" "$manager")"; then
    log "no package mapping for tool $tool on manager $manager"
    failed+=("$tool")
    continue
  fi

  log "installing $tool via package $pkg"
  if ! install_package "$pkg"; then
    log "failed to install: $tool"
    failed+=("$tool")
  fi

done

if ((${#failed[@]} > 0)); then
  printf 'ERROR: failed or unsupported tools: %s\n' "${failed[*]}" >&2
  exit 1
fi

log "k8s tool installation flow completed"
