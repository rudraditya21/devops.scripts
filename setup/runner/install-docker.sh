#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: install-docker.sh [OPTIONS]

Install Docker using the host package manager.

Options:
  --manager NAME               auto|brew|apt|dnf|yum (default: auto)
  --yes                        Non-interactive install mode
  --update-cache               Refresh package metadata before install
  --start-service              Start and enable Docker service on Linux (default)
  --no-start-service           Do not start Docker service
  --add-user-to-docker-group   Add current user to docker group (Linux)
  --dry-run                    Print commands without executing
  -h, --help                   Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [install-docker] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
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

install_docker_pkg() {
  case "$manager" in
    brew)
      run_cmd brew install --cask docker
      ;;
    apt)
      if $assume_yes; then
        as_root apt-get install -y docker.io
      else
        as_root apt-get install docker.io
      fi
      ;;
    dnf)
      if $assume_yes; then
        as_root dnf install -y docker
      else
        as_root dnf install docker
      fi
      ;;
    yum)
      if $assume_yes; then
        as_root yum install -y docker
      else
        as_root yum install docker
      fi
      ;;
    *)
      die "internal error: unsupported manager $manager"
      ;;
  esac
}

manager="auto"
assume_yes=false
update_cache=false
start_service=true
add_user_group=false
dry_run=false

while (($#)); do
  case "$1" in
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
    --start-service)
      start_service=true
      ;;
    --no-start-service)
      start_service=false
      ;;
    --add-user-to-docker-group)
      add_user_group=true
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

os_name="$(uname -s)"
if [[ "$os_name" != "Linux" && "$os_name" != "Darwin" ]]; then
  die "unsupported OS: $os_name"
fi

detect_manager
update_cache_if_needed

if command_exists docker; then
  log "docker already installed: $(command -v docker)"
else
  log "installing docker via $manager"
  install_docker_pkg
fi

if [[ "$os_name" == "Linux" ]]; then
  if $start_service && command_exists systemctl; then
    log "starting and enabling docker service"
    as_root systemctl enable --now docker
  fi

  if $add_user_group; then
    if getent group docker > /dev/null 2>&1; then
      :
    else
      log "creating docker group"
      as_root groupadd docker
    fi
    if [[ -n "${SUDO_USER:-}" ]]; then
      as_root usermod -aG docker "$SUDO_USER"
      log "added user $SUDO_USER to docker group"
    else
      as_root usermod -aG docker "$USER"
      log "added user $USER to docker group"
    fi
  fi
fi

log "docker installation flow completed"
