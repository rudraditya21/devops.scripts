# schema-diff.sh

## Purpose
Run `schema-diff.sh` for `sqlserver` database operations.

## Location
`databases/sqlserver/schema-diff.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target database and filesystem paths
- Required environment variables: none by default

## Usage
```bash
databases/sqlserver/schema-diff.sh --help
```

## Output
- Exit codes: `0` success, `1` strict check failure, `2` invalid arguments.
