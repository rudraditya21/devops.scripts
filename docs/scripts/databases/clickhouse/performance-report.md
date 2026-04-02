# performance-report.sh

## Purpose
Run `performance-report.sh` for `clickhouse` database operations.

## Location
`databases/clickhouse/performance-report.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target database and filesystem paths
- Required environment variables: none by default

## Usage
```bash
databases/clickhouse/performance-report.sh --help
```

## Output
- Exit codes: `0` success, `1` strict check failure, `2` invalid arguments.
