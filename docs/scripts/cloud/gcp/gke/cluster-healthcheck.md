# cluster-healthcheck.sh

## Purpose
Check GKE operational readiness: CLI availability, active account, project context, and optional cluster visibility.

## Location
`cloud/gcp/gke/cluster-healthcheck.sh`

## Preconditions
- Required tools: `bash`, `gcloud`
- Required permissions: `container.clusters.get` (if `--name` is used)
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name NAME` | No | none | Cluster name to verify |
| `--zone ZONE` | No | none | Cluster zone |
| `--region REGION` | No | none | Cluster region |
| `--project PROJECT` | No | gcloud/default | Project override |
| `--strict` | No | `false` | WARN treated as failure |
| `--json` | No | `false` | JSON output |

## Scenarios
- Happy path: all checks pass and optional cluster is reachable.
- Common operational path: run before GKE maintenance operations.
- Failure path: no active account or inaccessible cluster.
- Recovery/rollback path: re-authenticate and set project/location correctly.

## Usage
```bash
cloud/gcp/gke/cluster-healthcheck.sh --json
cloud/gcp/gke/cluster-healthcheck.sh --name app-gke --zone us-central1-a --strict
```

## Behavior
- Main execution flow:
  - validates argument combinations
  - checks `gcloud` binary and active identity
  - resolves project context and optionally cluster status
  - prints PASS/WARN/FAIL summary
- Idempotency notes: read-only and repeatable.
- Side effects: none.

## Output
- Standard output format: table (default) or JSON summary with check entries.
- Exit codes:
  - `0` no FAIL checks (and no WARN in strict mode)
  - `1` one or more FAIL checks (or WARN in strict mode)
  - `2` invalid arguments

## Failure Modes
- Common errors and likely causes:
  - gcloud not installed
  - no active gcloud account
  - cluster not found in selected location
- Recovery and rollback steps:
  - run `gcloud auth login`
  - set project with `gcloud config set project ...`
  - verify cluster location flags

## Security Notes
- Secret handling: no secrets emitted.
- Least-privilege requirements: read-only permissions for health checks.
- Audit/logging expectations: check output can be retained with deployment evidence.

## Testing
- Unit tests:
  - strict/json behavior and location validation
- Integration tests:
  - run with and without cluster name in test project
- Manual verification:
  - compare script output to direct gcloud command results
