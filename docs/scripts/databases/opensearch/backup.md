# backup.sh

## Purpose
Run `backup.sh` for `opensearch` database operations.

## Location
`databases/opensearch/backup.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target database and filesystem paths
- Required environment variables: none by default

## Usage
```bash
databases/opensearch/backup.sh --help
```

## Output
- Exit codes: `0` success, `1` strict check failure, `2` invalid arguments.
