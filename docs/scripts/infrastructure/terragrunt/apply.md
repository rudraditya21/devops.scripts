# apply.sh

## Purpose
Run `apply.sh` for `terragrunt` infrastructure workflows.

## Location
`infrastructure/terragrunt/apply.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target config/state/output paths
- Required environment variables: none

## Usage
```bash
infrastructure/terragrunt/apply.sh --help
```

## Output
- Exit codes: `0` success, `1` strict drift failure, `2` invalid arguments.
