# generate-changelog.sh

## Purpose
Generate categorized changelog output from commit history between two refs.

## Location
`git/generate-changelog.sh`

## Preconditions
- Required tools: `bash`, `git`, `date`, `sed`, `tr`
- Required permissions: read access to git history; write access when `--output` is used
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--from REF` | No | auto previous tag | Start reference |
| `--to REF` | No | `HEAD` | End reference |
| `--format FORMAT` | No | `markdown` | `markdown` or `plain` |
| `--output PATH` | No | stdout | Output file path |
| `--include-merges` | No | `false` | Include merge commits |
| `--max-commits N` | No | `500` | Commit cap for generation |
| `--title TEXT` | No | `Changelog` | Report title |

## Scenarios
- Happy path: changelog generated for previous release to `HEAD`.
- Common operational path: generate markdown for release PR/body.
- Failure path: invalid refs or no reachable tags for auto `--from`.
- Recovery/rollback path: provide explicit `--from` and regenerate.

## Usage
```bash
git/generate-changelog.sh --from v1.5.0 --to HEAD --output CHANGELOG_RELEASE.md
git/generate-changelog.sh --format plain --include-merges
git/generate-changelog.sh --to release/2.0 --title "Release 2.0 Notes"
```

## Behavior
- Main execution flow:
  - resolves range (`from..to`), with optional auto-detection of prior tag
  - scans git log records
  - classifies commits by conventional prefixes (`feat`, `fix`, etc.)
  - renders grouped output as markdown/plain
- Idempotency notes: deterministic for a fixed commit range and options.
- Side effects: none unless writing to `--output` file.

## Output
- Standard output format: grouped changelog sections (Features, Fixes, Performance, etc.).
- Exit codes:
  - `0` success
  - `2` invalid arguments/refs
  - git command exit code on log extraction failure

## Failure Modes
- Common errors and likely causes:
  - `start ref not found` or `end ref not found`
  - malformed `--max-commits`
  - empty range due incorrect refs
- Recovery and rollback steps:
  - validate refs with `git rev-parse`
  - pass explicit `--from`/`--to`
  - rerun with increased `--max-commits`

## Security Notes
- Secret handling: output may expose commit text containing sensitive terms; review before publishing.
- Least-privilege requirements: read-only repo access for stdout mode.
- Audit/logging expectations: generated changelog should be tied to release artifact IDs.

## Testing
- Unit tests:
  - range resolution and type classification
  - format rendering correctness
- Integration tests:
  - generation across tagged release ranges
  - empty-range behavior
- Manual verification:
  - compare generated output with `git log --oneline <from>..<to>`
