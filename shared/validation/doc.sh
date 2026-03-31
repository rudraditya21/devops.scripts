#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: doc.sh [OPTIONS]

Generate quick reference docs for the validation shared module.

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
# shared/validation Module

## Scripts
- `shared/validation/example.sh`: demonstrates command and env validation usage
- `shared/validation/test.sh`: smoke tests success and failure validation paths
- `shared/validation/doc.sh`: generates this quick reference

## Core Dependencies
- `shared/core/require-cmd.sh`
- `shared/core/require-env.sh`
MD
}

render_text() {
  cat << 'TXT'
shared/validation module

scripts:
- shared/validation/example.sh: validation usage examples
- shared/validation/test.sh: smoke tests for validation behavior
- shared/validation/doc.sh: quick reference generator

dependencies:
- shared/core/require-cmd.sh
- shared/core/require-env.sh
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
