# validate.sh

## Purpose
Run `validate.sh` for `terragrunt` infrastructure workflows.

## Location
`infrastructure/terragrunt/validate.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target config/state/output paths
- Required environment variables: none

## Usage
```bash
infrastructure/terragrunt/validate.sh --help
```

## Output
- Exit codes: `0` success, `1` strict drift failure, `2` invalid arguments.
