# rollback.sh

## Purpose
Run `rollback.sh` for `iam-audit` security workflows.

## Location
`security/iam-audit/rollback.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on selected target and output paths
- Required environment variables: none

## Usage
```bash
security/iam-audit/rollback.sh --help
```

## Output
- Exit codes: `0` success, `1` strict healthcheck failure, `2` invalid arguments.
