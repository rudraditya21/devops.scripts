#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: doc.sh [OPTIONS]

Generate quick reference docs for the timeout shared module.

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
# shared/timeout Module

## Scripts
- `shared/timeout/example.sh`: wraps `shared/safety/with-timeout.sh` with example defaults
- `shared/timeout/test.sh`: validates timeout, pass-through, and exit-code behavior
- `shared/timeout/doc.sh`: generates this quick reference

## Core Dependencies
- `shared/safety/with-timeout.sh`
MD
}

render_text() {
  cat << 'TXT'
shared/timeout module

scripts:
- shared/timeout/example.sh: timeout wrapper example
- shared/timeout/test.sh: smoke tests for timeout behavior
- shared/timeout/doc.sh: quick reference generator

dependencies:
- shared/safety/with-timeout.sh
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
