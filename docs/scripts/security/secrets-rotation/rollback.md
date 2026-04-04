# rollback.sh

## Purpose
Run `rollback.sh` for `secrets-rotation` security workflows.

## Location
`security/secrets-rotation/rollback.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on selected target and output paths
- Required environment variables: none

## Usage
```bash
security/secrets-rotation/rollback.sh --help
```

## Output
- Exit codes: `0` success, `1` strict healthcheck failure, `2` invalid arguments.
