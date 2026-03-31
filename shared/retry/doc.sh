#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: doc.sh [OPTIONS]

Generate quick reference docs for the retry shared module.

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
# shared/retry Module

## Scripts
- `shared/retry/example.sh`: wraps `shared/safety/retry.sh` with example defaults
- `shared/retry/test.sh`: validates retry success, exhaustion, and non-retryable behavior
- `shared/retry/doc.sh`: generates this quick reference

## Core Dependencies
- `shared/safety/retry.sh`
MD
}

render_text() {
  cat << 'TXT'
shared/retry module

scripts:
- shared/retry/example.sh: retry wrapper example
- shared/retry/test.sh: smoke tests for retry behavior
- shared/retry/doc.sh: quick reference generator

dependencies:
- shared/safety/retry.sh
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
