# configure.sh

## Purpose
Configure local database client files (`.pgpass`, `.my.cnf`) with optional templates.

## Location
`setup/db-tools/configure.sh`

## Preconditions
- Required tools: `bash`, `chmod`
- Required permissions: write access to user home config files
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--pgpass-file PATH` | No | `~/.pgpass` | PostgreSQL password file |
| `--my-cnf-file PATH` | No | `~/.my.cnf` | MySQL client config file |
| `--create-templates` | No | `false` | Create templates if missing |
| `--dry-run` | No | `false` | Print actions only |

## Usage
```bash
setup/db-tools/configure.sh --create-templates
```

## Behavior
- Optionally writes secure template files and applies mode `600`.

## Output
- Displays file status when present.

## Failure Modes
- Permission denied writing config files.

## Security Notes
- Restricts file permissions for credential-bearing files.

## Testing
- Verify files are created with correct permissions.
