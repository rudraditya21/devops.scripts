# healthcheck.sh

## Purpose
Run `healthcheck.sh` for `redis` database operations.

## Location
`databases/redis/healthcheck.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target database and filesystem paths
- Required environment variables: none by default

## Usage
```bash
databases/redis/healthcheck.sh --help
```

## Output
- Exit codes: `0` success, `1` strict check failure, `2` invalid arguments.
