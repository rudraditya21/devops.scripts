# plan.sh

## Purpose
Run `plan.sh` for `terragrunt` infrastructure workflows.

## Location
`infrastructure/terragrunt/plan.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target config/state/output paths
- Required environment variables: none

## Usage
```bash
infrastructure/terragrunt/plan.sh --help
```

## Output
- Exit codes: `0` success, `1` strict drift failure, `2` invalid arguments.
