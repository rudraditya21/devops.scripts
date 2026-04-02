# migrate.sh

## Purpose
Run `migrate.sh` for `mariadb` database operations.

## Location
`databases/mariadb/migrate.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target database and filesystem paths
- Required environment variables: none by default

## Usage
```bash
databases/mariadb/migrate.sh --help
```

## Output
- Exit codes: `0` success, `1` strict check failure, `2` invalid arguments.
