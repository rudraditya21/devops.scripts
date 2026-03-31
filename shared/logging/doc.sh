#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: doc.sh [OPTIONS]

Generate quick reference docs for the logging shared module.

Options:
  --format FORMAT    markdown|text (default: markdown)
  --output PATH      Write to file instead of stdout
  -h, --help         Show help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

format="markdown"
output=""

while (($#)); do
  case "$1" in
    --format)
      shift
      (($#)) || die "--format requires a value"
      format="$1"
      ;;
    --output)
      shift
      (($#)) || die "--output requires a value"
      output="$1"
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

render_markdown() {
  cat << 'MD'
# shared/logging Module

## Scripts
- `shared/logging/example.sh`: demonstrates `log-info.sh`, `log-warn.sh`, and `log-error.sh`
- `shared/logging/test.sh`: smoke tests output formatting and exit code behavior
- `shared/logging/doc.sh`: generates this quick reference

## Core Dependencies
- `shared/core/log-info.sh`
- `shared/core/log-warn.sh`
- `shared/core/log-error.sh`
MD
}

render_text() {
  cat << 'TXT'
shared/logging module

scripts:
- shared/logging/example.sh: demo runner for logging primitives
- shared/logging/test.sh: smoke tests for logging behavior
- shared/logging/doc.sh: quick reference generator

dependencies:
- shared/core/log-info.sh
- shared/core/log-warn.sh
- shared/core/log-error.sh
TXT
}

case "$format" in
  markdown)
    rendered="$(render_markdown)"
    ;;
  text)
    rendered="$(render_text)"
    ;;
  *)
    die "invalid --format: $format"
    ;;
esac

if [[ -n "$output" ]]; then
  printf '%s\n' "$rendered" > "$output"
else
  printf '%s\n' "$rendered"
fi
