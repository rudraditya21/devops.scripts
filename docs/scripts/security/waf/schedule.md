# schedule.sh

## Purpose
Run `schedule.sh` for `waf` security workflows.

## Location
`security/waf/schedule.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on selected target and output paths
- Required environment variables: none

## Usage
```bash
security/waf/schedule.sh --help
```

## Output
- Exit codes: `0` success, `1` strict healthcheck failure, `2` invalid arguments.
