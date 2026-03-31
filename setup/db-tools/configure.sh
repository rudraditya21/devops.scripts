#!/usr/bin/env bash
set -euo pipefail

usage(){ cat << 'USAGE'
Usage: configure.sh [OPTIONS]

Configure local database client defaults.

Options:
  --pgpass-file PATH      .pgpass file path (default: ~/.pgpass)
  --my-cnf-file PATH      MySQL client file path (default: ~/.my.cnf)
  --create-templates      Write template files when missing
  --dry-run               Print actions without executing
  -h, --help              Show help
USAGE
}

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 2; }
run_cmd(){ if $dry_run; then printf 'DRY-RUN:' >&2; printf ' %q' "$@" >&2; printf '\n' >&2; return 0; fi; "$@"; }

pgpass_file="$HOME/.pgpass"
my_cnf_file="$HOME/.my.cnf"
create_templates=false
dry_run=false

while (($#)); do
  case "$1" in
    --pgpass-file) shift; (($#)) || die "--pgpass-file requires a value"; pgpass_file="$1" ;;
    --my-cnf-file) shift; (($#)) || die "--my-cnf-file requires a value"; my_cnf_file="$1" ;;
    --create-templates) create_templates=true ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

if $create_templates; then
  if [[ ! -f "$pgpass_file" ]]; then
    if $dry_run; then
      printf 'DRY-RUN: write template %s\n' "$pgpass_file" >&2
    else
      cat > "$pgpass_file" <<PG
# hostname:port:database:username:password
PG
      chmod 600 "$pgpass_file"
    fi
  fi

  if [[ ! -f "$my_cnf_file" ]]; then
    if $dry_run; then
      printf 'DRY-RUN: write template %s\n' "$my_cnf_file" >&2
    else
      cat > "$my_cnf_file" <<MY
[client]
# user=example
# password=example
MY
      chmod 600 "$my_cnf_file"
    fi
  fi
fi

run_cmd ls -ld "$pgpass_file" "$my_cnf_file" 2> /dev/null || true
exit 0
