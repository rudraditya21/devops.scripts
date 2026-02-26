#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: configure-terraform.sh [OPTIONS]

Configure Terraform CLI defaults via managed ~/.terraformrc block.

Options:
  --config-file PATH       Terraform CLI config path (default: ~/.terraformrc)
  --plugin-cache-dir PATH  Plugin cache dir (default: ~/.terraform.d/plugin-cache)
  --disable-checkpoint B   true|false (default: true)
  --registry-host HOST     Credentials host (default: app.terraform.io)
  --token TOKEN            API token for credentials block
  --dry-run                Print planned file output
  -h, --help               Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

log() {
  printf '%s [configure-terraform] %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2
}

normalize_bool() {
  case "$1" in
    true | false) printf '%s' "$1" ;;
    1 | yes | on) printf 'true' ;;
    0 | no | off) printf 'false' ;;
    *) die "invalid boolean value: $1 (use true/false)" ;;
  esac
}

write_managed_block() {
  local cfg="$1"
  local source_cfg="$2"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/configure-terraform.XXXXXX")"

  awk '
    BEGIN { in_block=0 }
    /^# >>> devops\.scripts managed terraform >>>$/ { in_block=1; next }
    /^# <<< devops\.scripts managed terraform <<<$/ { in_block=0; next }
    in_block==0 { print }
  ' "$source_cfg" > "$tmp"

  {
    printf '\n'
    printf '# >>> devops.scripts managed terraform >>>\n'
    printf 'plugin_cache_dir = "%s"\n' "$plugin_cache_dir"
    printf 'disable_checkpoint = %s\n' "$disable_checkpoint"
    if [[ -n "$tf_token" ]]; then
      printf 'credentials "%s" {\n' "$registry_host"
      printf '  token = "%s"\n' "$tf_token"
      printf '}\n'
    fi
    printf '# <<< devops.scripts managed terraform <<<\n'
  } >> "$tmp"

  if $dry_run; then
    log "dry-run enabled; managed config for $cfg"
    cat "$tmp"
    rm -f "$tmp"
    return
  fi

  cp "$tmp" "$cfg"
  chmod 600 "$cfg"
  rm -f "$tmp"
}

config_file="$HOME/.terraformrc"
plugin_cache_dir="$HOME/.terraform.d/plugin-cache"
disable_checkpoint="true"
registry_host="app.terraform.io"
tf_token="${TF_TOKEN:-}"
dry_run=false
config_source=""
config_source_temp=""

while (($#)); do
  case "$1" in
    --config-file)
      shift
      (($#)) || die "--config-file requires a value"
      config_file="$1"
      ;;
    --plugin-cache-dir)
      shift
      (($#)) || die "--plugin-cache-dir requires a value"
      plugin_cache_dir="$1"
      ;;
    --disable-checkpoint)
      shift
      (($#)) || die "--disable-checkpoint requires a value"
      disable_checkpoint="$(normalize_bool "$1")"
      ;;
    --registry-host)
      shift
      (($#)) || die "--registry-host requires a value"
      registry_host="$1"
      ;;
    --token)
      shift
      (($#)) || die "--token requires a value"
      tf_token="$1"
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

trap 'rm -f "${config_source_temp:-}"' EXIT

if $dry_run; then
  if [[ ! -f "$config_file" ]]; then
    log "dry-run: create $(dirname "$config_file") and $config_file"
    config_source_temp="$(mktemp "${TMPDIR:-/tmp}/configure-terraform-source.XXXXXX")"
    config_source="$config_source_temp"
  else
    config_source="$config_file"
  fi
  log "dry-run: create $plugin_cache_dir"
else
  mkdir -p "$(dirname "$config_file")"
  mkdir -p "$plugin_cache_dir"
  if [[ ! -f "$config_file" ]]; then
    : > "$config_file"
    chmod 600 "$config_file"
  fi
  config_source="$config_file"
fi

write_managed_block "$config_file" "$config_source"
log "terraform configuration applied"
