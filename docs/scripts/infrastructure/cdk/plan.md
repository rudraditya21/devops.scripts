# plan.sh

## Purpose
Run `plan.sh` for `cdk` infrastructure workflows.

## Location
`infrastructure/cdk/plan.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target config/state/output paths
- Required environment variables: none

## Usage
```bash
infrastructure/cdk/plan.sh --help
```

## Output
- Exit codes: `0` success, `1` strict drift failure, `2` invalid arguments.
