#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: recommendations-export.sh [OPTIONS]

Export kubernetes cost optimization recommendations.

Options:
  --format FMT      csv|json (default: csv)
  --top N           Number of recommendations to export (default: 5)
  --output PATH     Write output to file instead of stdout
  --dry-run         Print actions without executing
  -h, --help        Show help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

format="csv"
top="5"
output_path=""
dry_run=false

while (($#)); do
  case "$1" in
    --format) shift; (($#)) || die "--format requires a value"; format="$1" ;;
    --top) shift; (($#)) || die "--top requires a value"; top="$1" ;;
    --output) shift; (($#)) || die "--output requires a value"; output_path="$1" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ "$top" =~ ^[1-9][0-9]*$ ]] || die "--top must be a positive integer"
case "$format" in csv|json) ;; *) die "--format must be csv or json" ;; esac

if [[ "$format" == "csv" ]]; then
  content="id,provider,resource,recommendation,estimated_monthly_savings\n"
  i=1
  while ((i <= top)); do
    content+="rec-${i},kubernetes,resource-${i},optimize-size-${i},$((i * 25))\n"
    i=$((i + 1))
  done
else
  content='['
  i=1
  while ((i <= top)); do
    item=$(printf '{"id":"rec-%s","provider":"kubernetes","resource":"resource-%s","recommendation":"optimize-size-%s","estimated_monthly_savings":%s}' "$i" "$i" "$i" "$((i * 25))")
    if ((i > 1)); then
      content+=','
    fi
    content+="$item"
    i=$((i + 1))
  done
  content+=']'
fi

if [[ -n "$output_path" ]]; then
  if $dry_run; then
    printf 'DRY-RUN: write recommendations to %s\n' "$output_path" >&2
  else
    mkdir -p "$(dirname "$output_path")"
    if [[ "$format" == "csv" ]]; then
      printf '%b' "$content" > "$output_path"
    else
      printf '%s\n' "$content" > "$output_path"
    fi
  fi
else
  if [[ "$format" == "csv" ]]; then
    printf '%b' "$content"
  else
    printf '%s\n' "$content"
  fi
fi

exit 0
