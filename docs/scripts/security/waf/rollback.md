# rollback.sh

## Purpose
Run `rollback.sh` for `waf` security workflows.

## Location
`security/waf/rollback.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on selected target and output paths
- Required environment variables: none

## Usage
```bash
security/waf/rollback.sh --help
```

## Output
- Exit codes: `0` success, `1` strict healthcheck failure, `2` invalid arguments.
