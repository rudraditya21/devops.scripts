# replication-check.sh

## Purpose
Run `replication-check.sh` for `sqlserver` database operations.

## Location
`databases/sqlserver/replication-check.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target database and filesystem paths
- Required environment variables: none by default

## Usage
```bash
databases/sqlserver/replication-check.sh --help
```

## Output
- Exit codes: `0` success, `1` strict check failure, `2` invalid arguments.
