#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'EOF'
Usage: tmpdir.sh [--prefix PREFIX] [--base-dir DIR] [--mode OCTAL] [--env-var NAME] [--keep] [-- COMMAND...]

Creates a secure temporary directory.

Without COMMAND:
  Prints created directory path to stdout.

With COMMAND:
  Exports the directory path through --env-var (default DEVOPS_TMPDIR),
  runs COMMAND, and removes the directory unless --keep is set.
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

prefix="devops"
base_dir="${TMPDIR:-/tmp}"
mode="700"
env_var="DEVOPS_TMPDIR"
keep=false
command=()

while (($#)); do
  case "$1" in
    --prefix)
      shift
      (($#)) || die "--prefix requires a value"
      prefix="$1"
      ;;
    --base-dir)
      shift
      (($#)) || die "--base-dir requires a value"
      base_dir="$1"
      ;;
    --mode)
      shift
      (($#)) || die "--mode requires a value"
      [[ "$1" =~ ^[0-7]{3,4}$ ]] || die "mode must be octal (e.g. 700)"
      mode="$1"
      ;;
    --env-var)
      shift
      (($#)) || die "--env-var requires a value"
      [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "invalid env var name: $1"
      env_var="$1"
      ;;
    --keep)
      keep=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      if (($#)); then
        command=("$@")
      fi
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      die "unexpected argument: $1 (use -- COMMAND to run a command)"
      ;;
  esac
  shift
done

[[ -d "$base_dir" ]] || die "base directory does not exist: $base_dir"
[[ -w "$base_dir" ]] || die "base directory is not writable: $base_dir"
[[ "$prefix" =~ ^[A-Za-z0-9._-]+$ ]] || die "prefix contains invalid characters"

template="${base_dir%/}/${prefix}.XXXXXX"
tmpdir_path="$(mktemp -d "$template")" || die "failed to create temporary directory"
chmod "$mode" "$tmpdir_path" || die "failed to set mode $mode on $tmpdir_path"

if ((${#command[@]} == 0)); then
  printf '%s\n' "$tmpdir_path"
  exit 0
fi

if [[ -z "$tmpdir_path" || "$tmpdir_path" == "/" ]]; then
  die "refusing to use unsafe temporary directory path"
fi

printf -v "$env_var" '%s' "$tmpdir_path"
export "${env_var?}"

set +e
"${command[@]}"
command_status=$?
set -e

cleanup_status=0
if ! $keep; then
  rm -rf -- "$tmpdir_path" || cleanup_status=$?
fi

if ((cleanup_status != 0)); then
  printf 'ERROR: failed to remove temporary directory: %s\n' "$tmpdir_path" >&2
  if ((command_status == 0)); then
    exit 70
  fi
fi

if $keep; then
  printf 'Temporary directory preserved: %s\n' "$tmpdir_path" >&2
fi

exit "$command_status"
