#!/usr/bin/env bash
set -euo pipefail

SCRIPT_TEST_PASSED=0
SCRIPT_TEST_FAILED=0

if [[ -t 1 ]]; then
  COLOR_GREEN='\033[32m'
  COLOR_RED='\033[31m'
  COLOR_RESET='\033[0m'
else
  COLOR_GREEN=''
  COLOR_RED=''
  COLOR_RESET=''
fi

print_pass() {
  local name="$1"
  printf '%b[PASSED]%b %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$name"
  SCRIPT_TEST_PASSED=$((SCRIPT_TEST_PASSED + 1))
}

print_fail() {
  local name="$1"
  local detail="${2-}"
  if [[ -n "$detail" ]]; then
    printf '%b[FAILED]%b %s :: %s\n' "$COLOR_RED" "$COLOR_RESET" "$name" "$detail"
  else
    printf '%b[FAILED]%b %s\n' "$COLOR_RED" "$COLOR_RESET" "$name"
  fi
  SCRIPT_TEST_FAILED=$((SCRIPT_TEST_FAILED + 1))
}

run_expect_exit() {
  local expected_exit="$1"
  local test_name="$2"
  shift 2

  local out_file err_file
  out_file="$(mktemp "${TMPDIR:-/tmp}/script-test.out.XXXXXX")"
  err_file="$(mktemp "${TMPDIR:-/tmp}/script-test.err.XXXXXX")"

  set +e
  "$@" >"$out_file" 2>"$err_file"
  local actual_exit=$?
  set -e

  if [[ "$actual_exit" -eq "$expected_exit" ]]; then
    print_pass "$test_name"
  else
    local detail
    detail="exit=$actual_exit expected=$expected_exit"
    print_fail "$test_name" "$detail"
  fi

  rm -f "$out_file" "$err_file"
}

run_expect_zero() {
  local test_name="$1"
  shift
  run_expect_exit 0 "$test_name" "$@"
}

run_expect_nonzero() {
  local test_name="$1"
  shift

  local out_file err_file
  out_file="$(mktemp "${TMPDIR:-/tmp}/script-test.out.XXXXXX")"
  err_file="$(mktemp "${TMPDIR:-/tmp}/script-test.err.XXXXXX")"

  set +e
  "$@" >"$out_file" 2>"$err_file"
  local actual_exit=$?
  set -e

  if [[ "$actual_exit" -ne 0 ]]; then
    print_pass "$test_name"
  else
    print_fail "$test_name" "exit=$actual_exit expected=non-zero"
  fi

  rm -f "$out_file" "$err_file"
}

normalize_script_path() {
  local script_path="$1"
  if [[ "$script_path" = /* ]]; then
    printf '%s\n' "$script_path"
  else
    printf '%s/%s\n' "$SCRIPT_TEST_ROOT" "$script_path"
  fi
}

is_numeric_flag() {
  local flag="$1"
  [[ "$flag" =~ (port|timeout|count|num|size|days|ms|percent|rate|qps|step|ttl|age|limit|lag|retry|attempt|parallel|workers|threshold|budget) ]]
}

value_for_flag() {
  local flag="$1"
  local placeholder="$2"
  local tmp_dir="$3"

  local name
  name="${flag#--}"

  case "$name" in
    host|target|server|hostname)
      printf '127.0.0.1\n'
      return
      ;;
    endpoint|url|uri|webhook)
      printf 'http://example.local\n'
      return
      ;;
    format)
      printf 'table\n'
      return
      ;;
    strategy)
      printf 'merge\n'
      return
      ;;
    channel)
      printf 'stable\n'
      return
      ;;
    namespace|scope|folder|profile|role)
      printf 'default\n'
      return
      ;;
    expr|query)
      printf 'up\n'
      return
      ;;
    start-date)
      printf '2026-01-01\n'
      return
      ;;
    end-date)
      printf '2026-01-02\n'
      return
      ;;
    from)
      printf 'now-1h\n'
      return
      ;;
    to)
      printf 'now\n'
      return
      ;;
    password-env)
      printf 'DB_PASSWORD\n'
      return
      ;;
    user|username|owner|db-user)
      printf 'tester\n'
      return
      ;;
    database|db|name|project|cluster)
      printf 'testdb\n'
      return
      ;;
  esac

  if [[ "$name" =~ (source|current|desired|input|file) ]]; then
    local file_path="$tmp_dir/${name}.txt"
    printf 'sample\n' > "$file_path"
    printf '%s\n' "$file_path"
    return
  fi

  if [[ "$name" =~ (dir|directory|path|output|destination|state|config|secret|manifest|log) ]]; then
    local path_val="$tmp_dir/${name}.out"
    printf '%s\n' "$path_val"
    return
  fi

  if [[ "$name" =~ migrations ]]; then
    local mdir="$tmp_dir/migrations"
    mkdir -p "$mdir"
    printf 'SELECT 1;\n' > "$mdir/001_init.sql"
    printf '%s\n' "$mdir"
    return
  fi

  if [[ "$placeholder" =~ YYYY-MM-DD ]]; then
    printf '2026-01-01\n'
    return
  fi

  if [[ "$placeholder" =~ [0-9] || "$placeholder" =~ (AMOUNT|N|PORT|SECONDS|MS|COUNT|PERCENT|QPS|TTL|SIZE) ]]; then
    printf '1\n'
    return
  fi

  if [[ "$placeholder" == *'|'* ]]; then
    printf '%s\n' "${placeholder%%|*}"
    return
  fi

  printf 'test-value\n'
}

invalid_value_for_flag() {
  local flag="$1"
  local placeholder="$2"
  local name="${flag#--}"

  if is_numeric_flag "$name" || [[ "$placeholder" =~ (PORT|N|SECONDS|MS|COUNT|PERCENT|QPS|SIZE|TTL|AMOUNT) ]]; then
    printf 'not-a-number\n'
    return
  fi

  if [[ "$name" =~ date || "$placeholder" =~ YYYY-MM-DD ]]; then
    printf 'not-a-date\n'
    return
  fi

  if [[ "$name" =~ format ]]; then
    printf '__bad_format__\n'
    return
  fi

  if [[ "$name" =~ strategy ]]; then
    printf '__bad_strategy__\n'
    return
  fi

  printf '__invalid__\n'
}

parse_usage_flags() {
  local script_file="$1"
  local out_file="$2"

  grep -E '^[[:space:]]+--[a-zA-Z0-9][a-zA-Z0-9-]*([[:space:]]+[^[:space:]]+)?[[:space:]]{2,}.*$' "$script_file" | \
    awk '
      {
        line=$0
        sub(/^[[:space:]]+/, "", line)
        flag=$1
        token2=$2
        required=(tolower(line) ~ /\(required\)/) ? "1" : "0"

        takes_value="0"
        placeholder=""
        if (token2 != "" && token2 !~ /^-/) {
          if (token2 ~ /[A-Z]/ || token2 ~ /\|/ || token2 ~ /^</ || token2 ~ /PATH|FILE|DIR|URL|NAME|CODE|FMT|VALUE|QUERY|TIME|DATE|AMOUNT|VERSION/) {
            takes_value="1"
            placeholder=token2
          }
        }

        print flag "|" takes_value "|" required "|" placeholder
      }
    ' | awk -F'|' '!seen[$1]++ { print $0 }' > "$out_file"
}

remove_flag_from_args() {
  local flag="$1"
  shift
  local -a source_args=("$@")
  local -a result=()
  local i=0
  while [[ $i -lt ${#source_args[@]} ]]; do
    if [[ "${source_args[$i]}" == "$flag" ]]; then
      i=$((i + 1))
      if [[ $i -lt ${#source_args[@]} ]] && [[ "${source_args[$i]}" != --* ]]; then
        i=$((i + 1))
      fi
      continue
    fi
    result+=("${source_args[$i]}")
    i=$((i + 1))
  done
  printf '%s\n' "${result[@]}"
}

run_script_suite() {
  local script_input="$1"
  local script_rel="$2"
  local script_abs
  script_abs="$(normalize_script_path "$script_input")"

  if [[ ! -f "$script_abs" ]]; then
    print_fail "$script_rel :: file exists" "missing script file"
    return
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/script-suite.XXXXXX")"
  trap 'rm -rf "$tmp_dir"' RETURN

  run_expect_zero "$script_rel :: --help exits 0" bash "$script_abs" --help
  run_expect_nonzero "$script_rel :: unknown option rejected" bash "$script_abs" --__invalid_option__

  local parsed_flags="$tmp_dir/flags.txt"
  parse_usage_flags "$script_abs" "$parsed_flags"

  declare -a base_args=()
  local has_dry_run=0

  while IFS='|' read -r flag takes_value required placeholder; do
    [[ -n "$flag" ]] || continue

    if [[ "$flag" == "--dry-run" ]]; then
      has_dry_run=1
    fi

    if [[ "$required" == "1" ]]; then
      if [[ "$takes_value" == "1" ]]; then
        base_args+=("$flag" "$(value_for_flag "$flag" "$placeholder" "$tmp_dir")")
      else
        base_args+=("$flag")
      fi
    fi
  done < "$parsed_flags"

  if [[ "$has_dry_run" == "1" ]]; then
    base_args+=("--dry-run")
  fi

  if [[ ${#base_args[@]} -gt 0 ]]; then
    run_expect_zero "$script_rel :: base invocation" bash "$script_abs" "${base_args[@]}"
  fi

  while IFS='|' read -r flag takes_value _required placeholder; do
    [[ -n "$flag" ]] || continue

    if [[ "$takes_value" == "1" ]]; then
      mapfile -t args_without_flag < <(remove_flag_from_args "$flag" "${base_args[@]}")

      run_expect_nonzero "$script_rel :: $flag missing value" \
        bash "$script_abs" "${args_without_flag[@]}" "$flag"

      run_expect_nonzero "$script_rel :: $flag invalid value" \
        bash "$script_abs" "${args_without_flag[@]}" "$flag" "$(invalid_value_for_flag "$flag" "$placeholder")"

      run_expect_zero "$script_rel :: $flag valid value" \
        bash "$script_abs" "${args_without_flag[@]}" "$flag" "$(value_for_flag "$flag" "$placeholder" "$tmp_dir")"
    else
      if [[ "$flag" == "--help" ]]; then
        continue
      fi

      mapfile -t args_without_flag < <(remove_flag_from_args "$flag" "${base_args[@]}")
      run_expect_zero "$script_rel :: $flag accepted" \
        bash "$script_abs" "${args_without_flag[@]}" "$flag"
    fi
  done < "$parsed_flags"

  if [[ "$SCRIPT_TEST_FAILED" -gt 0 ]]; then
    return 1
  fi

  return 0
}
