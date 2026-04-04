# plan.sh

## Purpose
Run `plan.sh` for `ansible` infrastructure workflows.

## Location
`infrastructure/ansible/plan.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target config/state/output paths
- Required environment variables: none

## Usage
```bash
infrastructure/ansible/plan.sh --help
```

## Output
- Exit codes: `0` success, `1` strict drift failure, `2` invalid arguments.
