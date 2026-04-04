# report.sh

## Purpose
Run `report.sh` for `sbom` security workflows.

## Location
`security/sbom/report.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on selected target and output paths
- Required environment variables: none

## Usage
```bash
security/sbom/report.sh --help
```

## Output
- Exit codes: `0` success, `1` strict healthcheck failure, `2` invalid arguments.
