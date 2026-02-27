# least-privilege-report.sh

## Purpose
Generate least-privilege risk signals from IAM Access Advisor service-last-accessed data.

## Location
`cloud/aws/iam/least-privilege-report.sh`

## Preconditions
- Required tools: `bash`, `aws`, `python3`
- Required permissions: `iam:GetUser`, `iam:GetRole`, `iam:GetGroup`, `iam:List*Policies`, `iam:GenerateServiceLastAccessedDetails`, `iam:GetServiceLastAccessedDetails`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--user NAME` / `--users CSV` | No | none | Target IAM users |
| `--role NAME` / `--roles CSV` | No | none | Target IAM roles |
| `--group NAME` / `--groups CSV` | No | none | Target IAM groups |
| `--unused-days N` | No | `90` | Threshold for stale service access |
| `--timeout SEC` | No | `600` | Access Advisor job timeout |
| `--poll-interval SEC` | No | `5` | Poll interval |
| `--profile PROFILE` | No | AWS default | AWS profile |
| `--output MODE` | No | `table` | `table\|json` |
| `--dry-run` | No | `false` | Print planned report actions |

## Scenarios
- Happy path: report highlights never-used/stale services per principal.
- Common operational path: periodic permission-rightsizing reviews for IAM identities.
- Failure path: Access Advisor job timeouts or missing generation/read permissions.
- Recovery/rollback path: rerun with larger timeout, narrower target set, and corrected IAM permissions.

## Usage
```bash
cloud/aws/iam/least-privilege-report.sh --roles app-runtime,ci-runner --unused-days 60
cloud/aws/iam/least-privilege-report.sh --user deploy-bot --output json
cloud/aws/iam/least-privilege-report.sh --profile security-audit --dry-run
```

## Behavior
- Main execution flow:
  - resolves principal ARNs
  - captures managed/inline policy counts
  - generates and polls Access Advisor jobs
  - counts never-used and stale services
  - outputs risk-oriented summary (`LOW|MEDIUM|HIGH`)
- Idempotency notes: read-only analysis with deterministic thresholds.
- Side effects: initiates IAM Access Advisor analysis jobs.

## Output
- Standard output format: table or JSON with principal counts and risk summary.
- Exit codes:
  - `0` success
  - `2` invalid input
  - non-zero on Access Advisor/API failures

## Failure Modes
- Common errors and likely causes:
  - access advisor generation or retrieval denied
  - timeout for large principal/service datasets
  - invalid principal names
- Recovery and rollback steps:
  - narrow scope (`--user/--role/--group`) and rerun
  - increase timeout/poll settings
  - validate identity permissions and principal existence

## Security Notes
- Secret handling: metadata-only; no credentials retrieved.
- Least-privilege requirements: read/report actions only for IAM analysis.
- Audit/logging expectations: results should feed periodic access reviews and remediation tracking.

## Testing
- Unit tests:
  - principal parsing and stale-service classification
- Integration tests:
  - report generation for known test principals with service usage history
- Manual verification:
  - compare service-last-accessed counts with IAM console Access Advisor
