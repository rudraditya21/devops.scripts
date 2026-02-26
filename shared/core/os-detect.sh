#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'EOF'
Usage: os-detect.sh [--output plain|env|json]

Detects normalized operating system and architecture metadata.
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

output_format="plain"
while (($#)); do
  case "$1" in
    --output)
      shift
      (($#)) || die "--output requires a value"
      case "$1" in
        plain | env | json) output_format="$1" ;;
        *) die "invalid output format: $1 (expected plain, env, or json)" ;;
      esac
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      die "unexpected argument: $1"
      ;;
  esac
  shift
done

uname_s="$(uname -s)"
uname_m="$(uname -m)"
kernel_release="$(uname -r)"

os_family="unknown"
os_name="unknown"
os_version="unknown"

case "$uname_s" in
  Darwin)
    os_family="darwin"
    os_name="macos"
    os_version="$(sw_vers -productVersion 2> /dev/null || true)"
    [[ -n "$os_version" ]] || os_version="unknown"
    ;;
  Linux)
    os_family="linux"
    if [[ -r /etc/os-release ]]; then
      os_name="$(awk -F= '$1=="ID"{gsub(/"/,"",$2); print $2}' /etc/os-release)"
      os_version="$(awk -F= '$1=="VERSION_ID"{gsub(/"/,"",$2); print $2}' /etc/os-release)"
      [[ -n "$os_name" ]] || os_name="linux"
      [[ -n "$os_version" ]] || os_version="unknown"
    else
      os_name="linux"
      os_version="unknown"
    fi
    ;;
  FreeBSD | OpenBSD | NetBSD)
    os_family="bsd"
    os_name="$(printf '%s' "$uname_s" | tr '[:upper:]' '[:lower:]')"
    os_version="$kernel_release"
    ;;
  CYGWIN* | MINGW* | MSYS*)
    os_family="windows"
    os_name="windows"
    os_version="$kernel_release"
    ;;
esac

case "$uname_m" in
  x86_64 | amd64) arch="amd64" ;;
  aarch64 | arm64) arch="arm64" ;;
  armv7l | armv7) arch="armv7" ;;
  armv6l | armv6) arch="armv6" ;;
  i386 | i686) arch="386" ;;
  *) arch="$uname_m" ;;
esac

case "$output_format" in
  plain)
    printf 'os_family=%s\n' "$os_family"
    printf 'os_name=%s\n' "$os_name"
    printf 'os_version=%s\n' "$os_version"
    printf 'arch=%s\n' "$arch"
    printf 'kernel_release=%s\n' "$kernel_release"
    ;;
  env)
    printf 'OS_FAMILY=%q\n' "$os_family"
    printf 'OS_NAME=%q\n' "$os_name"
    printf 'OS_VERSION=%q\n' "$os_version"
    printf 'ARCH=%q\n' "$arch"
    printf 'KERNEL_RELEASE=%q\n' "$kernel_release"
    ;;
  json)
    printf '{'
    printf '"os_family":"%s",' "$(json_escape "$os_family")"
    printf '"os_name":"%s",' "$(json_escape "$os_name")"
    printf '"os_version":"%s",' "$(json_escape "$os_version")"
    printf '"arch":"%s",' "$(json_escape "$arch")"
    printf '"kernel_release":"%s"' "$(json_escape "$kernel_release")"
    printf '}\n'
    ;;
esac
