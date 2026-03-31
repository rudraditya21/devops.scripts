#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: example.sh [OPTIONS]

Run validation examples using require-cmd and require-env scripts.

Options:
  --require-cmds LIST   Comma-separated commands (default: bash,awk)
  --require-envs LIST   Comma-separated vars (default: HOME,PATH)
  --allow-empty VAR     Variable allowed to be empty (repeatable)
  --json                Forward --json to validation scripts
  -h, --help            Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

require_cmds="bash,awk"
require_envs="HOME,PATH"
allow_empty=()
json=false

while (($#)); do
  case "$1" in
    --require-cmds)
      shift
      (($#)) || die "--require-cmds requires a value"
      require_cmds="$1"
      ;;
    --require-envs)
      shift
      (($#)) || die "--require-envs requires a value"
      require_envs="$1"
      ;;
    --allow-empty)
      shift
      (($#)) || die "--allow-empty requires a value"
      allow_empty+=("$1")
      ;;
    --json)
      json=true
      ;;
    -h|--help)
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

require_cmd_script="$repo_root/shared/core/require-cmd.sh"
require_env_script="$repo_root/shared/core/require-env.sh"

[[ -x "$require_cmd_script" ]] || die "missing dependency: $require_cmd_script"
[[ -x "$require_env_script" ]] || die "missing dependency: $require_env_script"

IFS=',' read -r -a cmd_items <<< "$require_cmds"
IFS=',' read -r -a env_items <<< "$require_envs"

cmd_args=()
for item in "${cmd_items[@]}"; do
  [[ -n "$item" ]] && cmd_args+=("$item")
done
((${#cmd_args[@]} > 0)) || die "--require-cmds resolved to an empty list"

env_args=()
for item in "${env_items[@]}"; do
  [[ -n "$item" ]] && env_args+=("$item")
done
((${#env_args[@]} > 0)) || die "--require-envs resolved to an empty list"

cmd_call=(bash "$require_cmd_script")
$json && cmd_call+=(--json)
cmd_call+=("${cmd_args[@]}")
"${cmd_call[@]}"

env_call=(bash "$require_env_script")
for item in "${allow_empty[@]}"; do
  env_call+=(--allow-empty "$item")
done
$json && env_call+=(--json)
env_call+=("${env_args[@]}")
"${env_call[@]}"
