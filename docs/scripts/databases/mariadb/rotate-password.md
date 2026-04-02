# rotate-password.sh

## Purpose
Run `rotate-password.sh` for `mariadb` database operations.

## Location
`databases/mariadb/rotate-password.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target database and filesystem paths
- Required environment variables: none by default

## Usage
```bash
databases/mariadb/rotate-password.sh --help
```

## Output
- Exit codes: `0` success, `1` strict check failure, `2` invalid arguments.
