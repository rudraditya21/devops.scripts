# migrate.sh

## Purpose
Run `migrate.sh` for `postgres` database operations.

## Location
`databases/postgres/migrate.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target database and filesystem paths
- Required environment variables: none by default

## Usage
```bash
databases/postgres/migrate.sh --help
```

## Output
- Exit codes: `0` success, `1` strict check failure, `2` invalid arguments.
