# destroy.sh

## Purpose
Run `destroy.sh` for `pulumi` infrastructure workflows.

## Location
`infrastructure/pulumi/destroy.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target config/state/output paths
- Required environment variables: none

## Usage
```bash
infrastructure/pulumi/destroy.sh --help
```

## Output
- Exit codes: `0` success, `1` strict drift failure, `2` invalid arguments.
