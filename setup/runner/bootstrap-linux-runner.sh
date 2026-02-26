#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: bootstrap-linux-runner.sh [OPTIONS]

Bootstrap a Linux CI/automation runner with local setup scripts.

Options:
  --manager NAME      auto|apt|dnf|yum|brew (default: auto)
  --yes               Non-interactive install mode
  --dry-run           Print actions without executing
  --update-cache      Refresh package metadata in installer scripts
  --skip-docker       Skip Docker installation
  --skip-k8s          Skip Kubernetes tool installation
  --skip-cloud        Skip cloud CLI installation
  --skip-healthcheck  Skip runner healthcheck
  -h, --help          Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [bootstrap-linux-runner] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

run_step() {
  local title="$1"
  shift
  log "running step: $title"
  "$@"
}

[[ "$(uname -s)" == "Linux" ]] || die "this script must run on Linux"

manager="auto"
assume_yes=false
dry_run=false
update_cache=false
skip_docker=false
skip_k8s=false
skip_cloud=false
skip_healthcheck=false

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
    --dry-run)
      dry_run=true
      ;;
    --update-cache)
      update_cache=true
      ;;
    --skip-docker)
      skip_docker=true
      ;;
    --skip-k8s)
      skip_k8s=true
      ;;
    --skip-cloud)
      skip_cloud=true
      ;;
    --skip-healthcheck)
      skip_healthcheck=true
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
local_setup_dir="$repo_root/setup/local"
runner_setup_dir="$repo_root/setup/runner"

common_flags=(--manager "$manager")
$assume_yes && common_flags+=(--yes)
$dry_run && common_flags+=(--dry-run)
$update_cache && common_flags+=(--update-cache)
local_cfg_flags=()
$dry_run && local_cfg_flags+=(--dry-run)

run_step "install base cli tools" \
  bash "$local_setup_dir/install-cli-tools.sh" \
  "${common_flags[@]}" \
  --tools git,curl,jq,yq,shellcheck,shfmt,gh,gpg,terraform

if ! $skip_docker; then
  run_step "install docker" bash "$runner_setup_dir/install-docker.sh" "${common_flags[@]}" --start-service
fi

if ! $skip_k8s; then
  run_step "install k8s tools" bash "$runner_setup_dir/install-k8s-tools.sh" "${common_flags[@]}"
fi

if ! $skip_cloud; then
  run_step "install cloud CLIs" bash "$runner_setup_dir/install-cloud-clis.sh" "${common_flags[@]}"
fi

run_step "configure git defaults" bash "$local_setup_dir/configure-git.sh" --rebase-pull false "${local_cfg_flags[@]}"
run_step "configure terraform defaults" bash "$local_setup_dir/configure-terraform.sh" "${local_cfg_flags[@]}"

if ! $skip_healthcheck; then
  health_flags=()
  $dry_run && health_flags+=(--json)
  run_step "runner healthcheck" bash "$runner_setup_dir/runner-healthcheck.sh" "${health_flags[@]}"
fi

log "linux runner bootstrap completed"
