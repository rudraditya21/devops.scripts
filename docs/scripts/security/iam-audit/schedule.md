# schedule.sh

## Purpose
Run `schedule.sh` for `iam-audit` security workflows.

## Location
`security/iam-audit/schedule.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on selected target and output paths
- Required environment variables: none

## Usage
```bash
security/iam-audit/schedule.sh --help
```

## Output
- Exit codes: `0` success, `1` strict healthcheck failure, `2` invalid arguments.
