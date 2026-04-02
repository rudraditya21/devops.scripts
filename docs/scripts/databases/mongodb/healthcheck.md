# healthcheck.sh

## Purpose
Run `healthcheck.sh` for `mongodb` database operations.

## Location
`databases/mongodb/healthcheck.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target database and filesystem paths
- Required environment variables: none by default

## Usage
```bash
databases/mongodb/healthcheck.sh --help
```

## Output
- Exit codes: `0` success, `1` strict check failure, `2` invalid arguments.
