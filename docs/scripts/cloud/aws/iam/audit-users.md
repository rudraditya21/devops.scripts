# audit-users.sh

## Purpose
Audit IAM users for high-risk identity hygiene issues (MFA posture and access-key age/state).

## Location
`cloud/aws/iam/audit-users.sh`

## Preconditions
- Required tools: `bash`, `aws`, `python3`
- Required permissions: `iam:ListUsers`, `iam:GetUser`, `iam:ListMFADevices`, `iam:GetLoginProfile`, `iam:ListAccessKeys`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--profile PROFILE` | No | AWS default | AWS profile |
| `--max-key-age-days N` | No | `90` | Threshold for old active access keys |
| `--output MODE` | No | `table` | `table\|json` |
| `--only-findings` | No | `false` | Emit only non-compliant users |

## Scenarios
- Happy path: script produces compliance-focused user inventory.
- Common operational path: scheduled IAM hygiene scans for security reporting.
- Failure path: missing read permissions for MFA/login/access-key APIs.
- Recovery/rollback path: grant audit role read-only IAM permissions and rerun.

## Usage
```bash
cloud/aws/iam/audit-users.sh
cloud/aws/iam/audit-users.sh --max-key-age-days 60 --only-findings
cloud/aws/iam/audit-users.sh --profile security-audit --output json
```

## Behavior
- Main execution flow:
  - enumerates IAM users
  - checks MFA devices and console login profile presence
  - evaluates active key count and key age threshold
  - emits findings (`console-without-mfa`, `multiple-active-keys`, `old-active-keys`)
- Idempotency notes: read-only diagnostic workflow.
- Side effects: none.

## Output
- Standard output format: compliance table or JSON report.
- Exit codes:
  - `0` success
  - `2` invalid arguments
  - non-zero on API/permission/runtime failures

## Failure Modes
- Common errors and likely causes:
  - absent IAM read permissions
  - missing `python3` for age calculations
  - partial API failures due principal constraints
- Recovery and rollback steps:
  - run with dedicated read-only audit role
  - install python3 in execution environment
  - re-run and compare with previous report snapshots

## Security Notes
- Secret handling: no secret values retrieved; metadata-only assessment.
- Least-privilege requirements: IAM read-only permissions sufficient.
- Audit/logging expectations: reports should be retained as evidence for periodic access reviews.

## Testing
- Unit tests:
  - finding classification logic and output rendering
- Integration tests:
  - users with varied MFA/key states in sandbox
- Manual verification:
  - compare findings against IAM console and raw API outputs
