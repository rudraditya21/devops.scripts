# state-backup.sh

## Purpose
Run `state-backup.sh` for `packer` infrastructure workflows.

## Location
`infrastructure/packer/state-backup.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: depends on target config/state/output paths
- Required environment variables: none

## Usage
```bash
infrastructure/packer/state-backup.sh --help
```

## Output
- Exit codes: `0` success, `1` strict drift failure, `2` invalid arguments.
