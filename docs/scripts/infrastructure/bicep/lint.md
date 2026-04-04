# lint.sh

## Purpose
Run `lint.sh` for `bicep` infrastructure workflows.

## Location
`infrastructure/bicep/lint.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target config/state/output paths
- Required environment variables: none

## Usage
```bash
infrastructure/bicep/lint.sh --help
```

## Output
- Exit codes: `0` success, `1` strict drift failure, `2` invalid arguments.
