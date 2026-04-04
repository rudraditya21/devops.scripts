# drift-detect.sh

## Purpose
Run `drift-detect.sh` for `packer` infrastructure workflows.

## Location
`infrastructure/packer/drift-detect.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target config/state/output paths
- Required environment variables: none

## Usage
```bash
infrastructure/packer/drift-detect.sh --help
```

## Output
- Exit codes: `0` success, `1` strict drift failure, `2` invalid arguments.
