# os-detect.sh

## Purpose
Detect normalized OS and architecture metadata for cross-platform script branching.

## Location
`shared/core/os-detect.sh`

## Preconditions
- Required tools: `bash`, `uname`, and on Linux optionally `/etc/os-release`
- Required permissions: read access to OS metadata files
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--output plain\|env\|json` | No | `plain` | Output representation |

## Scenarios
- Happy path: detect OS/arch and print key-value output.
- Common operational path: emit `env` output and `eval` in wrapper scripts.
- Failure path: unsupported argument value exits `2`.
- Recovery/rollback path: fix invocation flags; fallback values are `unknown` for missing metadata.

## Usage
```bash
shared/core/os-detect.sh
shared/core/os-detect.sh --output json
shared/core/os-detect.sh --output env
```

## Behavior
- Main execution flow:
  - parse output format
  - collect kernel and architecture via `uname`
  - map OS family/name/version from platform-specific sources
  - emit chosen output format
- Idempotency notes: deterministic for host state.
- Side effects: none.

## Output
- Standard output format fields:
  - `os_family`
  - `os_name`
  - `os_version`
  - `arch`
  - `kernel_release`
- Exit codes:
  - `0` success
  - `2` invalid argument/input usage

## Failure Modes
- Common errors and likely causes:
  - invalid `--output` value
  - metadata source unavailable (results may become `unknown`)
- Recovery and rollback steps:
  - pass valid output choice (`plain`, `env`, `json`)
  - tolerate `unknown` values in calling logic with sensible defaults

## Security Notes
- Secret handling: no secret access.
- Least-privilege requirements: read-only system metadata calls.
- Audit/logging expectations: safe to log in full.

## Testing
- Unit tests:
  - output mode validation
  - arch normalization mapping
- Integration tests:
  - platform-specific test matrix in CI
- Manual verification:
  - compare output across macOS/Linux hosts
