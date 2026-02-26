#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: setup-gpg.sh [OPTIONS]

Configure local GPG setup with optional key imports and managed gpg.conf block.

Options:
  --public-key FILE        Import public key file (repeatable)
  --private-key FILE       Import private key file (repeatable)
  --ownertrust FILE        Import ownertrust file
  --default-key KEYID      Set default signing key in managed config
  --pinentry-program PATH  Set pinentry program in managed config
  --dry-run                Print actions without executing
  -h, --help               Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [setup-gpg] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

run_cmd() {
  if $dry_run; then
    printf 'DRY-RUN: %s\n' "$*" >&2
    return 0
  fi
  "$@"
}

ensure_tool() {
  command -v gpg > /dev/null 2>&1 || die "gpg is required but not found"
}

write_managed_gpg_conf() {
  local cfg="$1"
  local source_cfg="$2"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/setup-gpg-conf.XXXXXX")"

  awk '
    BEGIN { in_block=0 }
    /^# >>> devops\.scripts managed gpg >>>$/ { in_block=1; next }
    /^# <<< devops\.scripts managed gpg <<<$/ { in_block=0; next }
    in_block==0 { print }
  ' "$source_cfg" > "$tmp"

  {
    printf '\n'
    printf '# >>> devops.scripts managed gpg >>>\n'
    printf 'use-agent\n'
    if [[ -n "$default_key" ]]; then
      printf 'default-key %s\n' "$default_key"
    fi
    if [[ -n "$pinentry_program" ]]; then
      printf 'pinentry-program %s\n' "$pinentry_program"
    fi
    printf '# <<< devops.scripts managed gpg <<<\n'
  } >> "$tmp"

  if $dry_run; then
    log "dry-run enabled; updated gpg.conf for $cfg"
    cat "$tmp"
    rm -f "$tmp"
    return
  fi

  cp "$tmp" "$cfg"
  chmod 600 "$cfg"
  rm -f "$tmp"
}

public_keys=()
private_keys=()
ownertrust_file=""
default_key=""
pinentry_program=""
dry_run=false
gpg_source=""
gpg_source_temp=""

while (($#)); do
  case "$1" in
    --public-key)
      shift
      (($#)) || die "--public-key requires a value"
      public_keys+=("$1")
      ;;
    --private-key)
      shift
      (($#)) || die "--private-key requires a value"
      private_keys+=("$1")
      ;;
    --ownertrust)
      shift
      (($#)) || die "--ownertrust requires a value"
      ownertrust_file="$1"
      ;;
    --default-key)
      shift
      (($#)) || die "--default-key requires a value"
      default_key="$1"
      ;;
    --pinentry-program)
      shift
      (($#)) || die "--pinentry-program requires a value"
      pinentry_program="$1"
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

ensure_tool

gnupg_dir="$HOME/.gnupg"
gpg_conf="$gnupg_dir/gpg.conf"
trap 'rm -f "${gpg_source_temp:-}"' EXIT

run_cmd mkdir -p "$gnupg_dir"
run_cmd chmod 700 "$gnupg_dir"

if [[ ! -f "$gpg_conf" ]]; then
  if $dry_run; then
    log "dry-run: create $gpg_conf"
    gpg_source_temp="$(mktemp "${TMPDIR:-/tmp}/setup-gpg-source.XXXXXX")"
    gpg_source="$gpg_source_temp"
  else
    : > "$gpg_conf"
    chmod 600 "$gpg_conf"
    gpg_source="$gpg_conf"
  fi
else
  gpg_source="$gpg_conf"
fi

key_file=""
for key_file in "${public_keys[@]}"; do
  [[ -r "$key_file" ]] || die "public key file not readable: $key_file"
  run_cmd gpg --import "$key_file"
done

for key_file in "${private_keys[@]}"; do
  [[ -r "$key_file" ]] || die "private key file not readable: $key_file"
  run_cmd gpg --import "$key_file"
done

if [[ -n "$ownertrust_file" ]]; then
  [[ -r "$ownertrust_file" ]] || die "ownertrust file not readable: $ownertrust_file"
  run_cmd gpg --import-ownertrust "$ownertrust_file"
fi

write_managed_gpg_conf "$gpg_conf" "$gpg_source"
run_cmd gpgconf --launch gpg-agent
log "gpg setup complete"
