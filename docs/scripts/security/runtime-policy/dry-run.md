# dry-run.sh

## Purpose
Run `dry-run.sh` for `runtime-policy` security workflows.

## Location
`security/runtime-policy/dry-run.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on selected target and output paths
- Required environment variables: none

## Usage
```bash
security/runtime-policy/dry-run.sh --help
```

## Output
- Exit codes: `0` success, `1` strict healthcheck failure, `2` invalid arguments.
