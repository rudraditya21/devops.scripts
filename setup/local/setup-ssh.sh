#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: setup-ssh.sh [OPTIONS]

Initialize SSH directory, optional key pair, and managed SSH client config.

Options:
  --key-file PATH      SSH private key file path (default: ~/.ssh/id_ed25519)
  --email EMAIL        Key comment value (default: USER@HOST)
  --key-type TYPE      ed25519|rsa (default: ed25519)
  --rsa-bits N         RSA bits when --key-type rsa (default: 4096)
  --no-generate-key    Skip key generation
  --force-key          Replace existing key file if present
  --dry-run            Print actions without executing
  -h, --help           Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [setup-ssh] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

run_cmd() {
  if $dry_run; then
    printf 'DRY-RUN: %s\n' "$*" >&2
    return 0
  fi
  "$@"
}

write_managed_config() {
  local cfg="$1"
  local source_cfg="$2"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/setup-ssh-config.XXXXXX")"

  awk '
    BEGIN { in_block=0 }
    /^# >>> devops\.scripts managed ssh >>>$/ { in_block=1; next }
    /^# <<< devops\.scripts managed ssh <<<$/ { in_block=0; next }
    in_block==0 { print }
  ' "$source_cfg" > "$tmp"

  {
    printf '\n'
    printf '# >>> devops.scripts managed ssh >>>\n'
    printf 'Host *\n'
    printf '  AddKeysToAgent yes\n'
    printf '  ServerAliveInterval 30\n'
    printf '  ServerAliveCountMax 3\n'
    if [[ "$os_name" == "darwin" ]]; then
      printf '  UseKeychain yes\n'
    fi
    printf '# <<< devops.scripts managed ssh <<<\n'
  } >> "$tmp"

  if $dry_run; then
    log "dry-run enabled; updated ssh config content for $cfg"
    cat "$tmp"
    rm -f "$tmp"
    return
  fi

  cp "$tmp" "$cfg"
  chmod 600 "$cfg"
  rm -f "$tmp"
}

key_file="$HOME/.ssh/id_ed25519"
email="${USER:-user}@$(hostname 2> /dev/null || printf localhost)"
key_type="ed25519"
rsa_bits="4096"
generate_key=true
force_key=false
dry_run=false
config_source=""
config_source_temp=""

while (($#)); do
  case "$1" in
    --key-file)
      shift
      (($#)) || die "--key-file requires a value"
      key_file="$1"
      ;;
    --email)
      shift
      (($#)) || die "--email requires a value"
      email="$1"
      ;;
    --key-type)
      shift
      (($#)) || die "--key-type requires a value"
      case "$1" in
        ed25519 | rsa) key_type="$1" ;;
        *) die "--key-type must be ed25519 or rsa" ;;
      esac
      ;;
    --rsa-bits)
      shift
      (($#)) || die "--rsa-bits requires a value"
      [[ "$1" =~ ^[0-9]+$ ]] || die "--rsa-bits must be numeric"
      rsa_bits="$1"
      ;;
    --no-generate-key)
      generate_key=false
      ;;
    --force-key)
      force_key=true
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

[[ -n "$email" ]] || die "email cannot be empty"

os_name="$(uname -s | tr '[:upper:]' '[:lower:]')"
ssh_dir="$(dirname "$key_file")"
config_file="$ssh_dir/config"
trap 'rm -f "${config_source_temp:-}"' EXIT

run_cmd mkdir -p "$ssh_dir"
run_cmd chmod 700 "$ssh_dir"

if [[ ! -f "$config_file" ]]; then
  if $dry_run; then
    log "dry-run: create $config_file"
    config_source_temp="$(mktemp "${TMPDIR:-/tmp}/setup-ssh-config-source.XXXXXX")"
    config_source="$config_source_temp"
  else
    : > "$config_file"
    chmod 600 "$config_file"
    config_source="$config_file"
  fi
else
  config_source="$config_file"
fi

if $generate_key; then
  if [[ -f "$key_file" ]] && ! $force_key; then
    log "key already exists at $key_file (use --force-key to regenerate)"
  else
    if [[ -f "$key_file" ]] && $force_key; then
      run_cmd rm -f "$key_file" "$key_file.pub"
    fi

    if [[ "$key_type" == "ed25519" ]]; then
      run_cmd ssh-keygen -t ed25519 -a 100 -f "$key_file" -N '' -C "$email"
    else
      run_cmd ssh-keygen -t rsa -b "$rsa_bits" -f "$key_file" -N '' -C "$email"
    fi
  fi
fi

write_managed_config "$config_file" "$config_source"
log "ssh setup complete"
