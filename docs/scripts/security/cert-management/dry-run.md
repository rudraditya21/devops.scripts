# dry-run.sh

## Purpose
Run `dry-run.sh` for `cert-management` security workflows.

## Location
`security/cert-management/dry-run.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on selected target and output paths
- Required environment variables: none

## Usage
```bash
security/cert-management/dry-run.sh --help
```

## Output
- Exit codes: `0` success, `1` strict healthcheck failure, `2` invalid arguments.
