# delete.sh

## Purpose
Run `delete` for `cidr` networking objects using validated flags.

## Location
`networking/cidr/delete.sh`

## Preconditions
- Required tools: `bash`
- Required permissions: none for dry-run/inspection workflows
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name NAME` | Yes | N/A | Object name |
| `--target VALUE` | No | empty | Target group/resource |
| `--cidr CIDR` | No | empty | CIDR value |
| `--json` | No | `false` | Emit JSON output |
| `--dry-run` | No | `false` | Print intended action |

## Usage
```bash
networking/cidr/delete.sh --name app-edge --target prod --cidr 10.10.0.0/24 --dry-run
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
