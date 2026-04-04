# plan.sh

## Purpose
Run `plan.sh` for `crossplane` infrastructure workflows.

## Location
`infrastructure/crossplane/plan.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target config/state/output paths
- Required environment variables: none

## Usage
```bash
infrastructure/crossplane/plan.sh --help
```

## Output
- Exit codes: `0` success, `1` strict drift failure, `2` invalid arguments.
