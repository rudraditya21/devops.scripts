# run.sh

## Purpose
Run `run.sh` for `secrets-rotation` security workflows.

## Location
`security/secrets-rotation/run.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on selected target and output paths
- Required environment variables: none

## Usage
```bash
security/secrets-rotation/run.sh --help
```

## Output
- Exit codes: `0` success, `1` strict healthcheck failure, `2` invalid arguments.
