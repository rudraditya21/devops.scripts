# enforce.sh

## Purpose
Run `enforce.sh` for `runtime-policy` security workflows.

## Location
`security/runtime-policy/enforce.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on selected target and output paths
- Required environment variables: none

## Usage
```bash
security/runtime-policy/enforce.sh --help
```

## Output
- Exit codes: `0` success, `1` strict healthcheck failure, `2` invalid arguments.
