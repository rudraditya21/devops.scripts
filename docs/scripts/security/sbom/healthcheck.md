# healthcheck.sh

## Purpose
Run `healthcheck.sh` for `sbom` security workflows.

## Location
`security/sbom/healthcheck.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on selected target and output paths
- Required environment variables: none

## Usage
```bash
security/sbom/healthcheck.sh --help
```

## Output
- Exit codes: `0` success, `1` strict healthcheck failure, `2` invalid arguments.
