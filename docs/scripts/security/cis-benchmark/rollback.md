# rollback.sh

## Purpose
Run `rollback.sh` for `cis-benchmark` security workflows.

## Location
`security/cis-benchmark/rollback.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on selected target and output paths
- Required environment variables: none

## Usage
```bash
security/cis-benchmark/rollback.sh --help
```

## Output
- Exit codes: `0` success, `1` strict healthcheck failure, `2` invalid arguments.
