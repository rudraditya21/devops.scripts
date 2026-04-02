# replication-check.sh

## Purpose
Run `replication-check.sh` for `clickhouse` database operations.

## Location
`databases/clickhouse/replication-check.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target database and filesystem paths
- Required environment variables: none by default

## Usage
```bash
databases/clickhouse/replication-check.sh --help
```

## Output
- Exit codes: `0` success, `1` strict check failure, `2` invalid arguments.
