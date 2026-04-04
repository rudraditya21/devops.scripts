# enforce.sh

## Purpose
Run `enforce.sh` for `secrets-rotation` security workflows.

## Location
`security/secrets-rotation/enforce.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on selected target and output paths
- Required environment variables: none

## Usage
```bash
security/secrets-rotation/enforce.sh --help
```

## Output
- Exit codes: `0` success, `1` strict healthcheck failure, `2` invalid arguments.
