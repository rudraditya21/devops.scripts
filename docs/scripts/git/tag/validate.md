# validate.sh

## Purpose
Validate `tag` values against policy regex constraints.

## Location
`git/tag/validate.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: none
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--value TEXT` | Yes | N/A | Value to validate |
| `--pattern REGEX` | No | `^[A-Za-z0-9._/-]+$` | Validation regex |
| `--json` | No | `false` | Emit JSON output |
| `--fail-on-invalid` | No | `false` | Exit non-zero when invalid |

## Usage
```bash
git/tag/validate.sh --value release/2026-04 --fail-on-invalid
```

## Output
- Exit codes: `0` valid/success, `1` invalid with fail mode, `2` invalid arguments.
