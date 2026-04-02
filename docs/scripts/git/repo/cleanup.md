# cleanup.sh

## Purpose
Cleanup stale `repo` git artifacts by age and pattern.

## Location
`git/repo/cleanup.sh`

## Preconditions
- Required tools: `bash`, `find`
- Required permissions: delete permission on target path
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--path DIR` | No | `.git` | Directory to clean |
| `--days N` | No | `30` | Age threshold |
| `--pattern GLOB` | No | `*` | File glob |
| `--dry-run` | No | `false` | Print matches only |

## Usage
```bash
git/repo/cleanup.sh --path .git --days 7 --pattern '*tmp*' --dry-run
```

## Output
- Exit codes: `0` success, `2` invalid arguments.
