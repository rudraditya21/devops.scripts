# replication-check.sh

## Purpose
Run `replication-check.sh` for `neo4j` database operations.

## Location
`databases/neo4j/replication-check.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target database and filesystem paths
- Required environment variables: none by default

## Usage
```bash
databases/neo4j/replication-check.sh --help
```

## Output
- Exit codes: `0` success, `1` strict check failure, `2` invalid arguments.
