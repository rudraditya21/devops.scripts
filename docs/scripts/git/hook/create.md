# create.sh

## Purpose
Create `hook` git metadata/object scaffolding.

## Location
`git/hook/create.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: write access when materializing outputs
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name NAME` | Yes | N/A | Name/identifier |
| `--metadata KV` | No | none | Metadata pair (repeatable) |
| `--json` | No | `false` | Emit JSON output |
| `--dry-run` | No | `false` | Print actions only |

## Usage
```bash
git/hook/create.sh --name demo-item --metadata owner=sre --dry-run
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
