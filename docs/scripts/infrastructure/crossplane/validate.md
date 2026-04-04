# validate.sh

## Purpose
Run `validate.sh` for `crossplane` infrastructure workflows.

## Location
`infrastructure/crossplane/validate.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target config/state/output paths
- Required environment variables: none

## Usage
```bash
infrastructure/crossplane/validate.sh --help
```

## Output
- Exit codes: `0` success, `1` strict drift failure, `2` invalid arguments.
