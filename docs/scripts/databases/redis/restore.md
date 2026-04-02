# restore.sh

## Purpose
Run `restore.sh` for `redis` database operations.

## Location
`databases/redis/restore.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target database and filesystem paths
- Required environment variables: none by default

## Usage
```bash
databases/redis/restore.sh --help
```

## Output
- Exit codes: `0` success, `1` strict check failure, `2` invalid arguments.
