# migrate.sh

## Purpose
Run `migrate.sh` for `elasticsearch` database operations.

## Location
`databases/elasticsearch/migrate.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target database and filesystem paths
- Required environment variables: none by default

## Usage
```bash
databases/elasticsearch/migrate.sh --help
```

## Output
- Exit codes: `0` success, `1` strict check failure, `2` invalid arguments.
