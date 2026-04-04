# healthcheck.sh

## Purpose
Run `healthcheck.sh` for `cis-benchmark` security workflows.

## Location
`security/cis-benchmark/healthcheck.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on selected target and output paths
- Required environment variables: none

## Usage
```bash
security/cis-benchmark/healthcheck.sh --help
```

## Output
- Exit codes: `0` success, `1` strict healthcheck failure, `2` invalid arguments.
