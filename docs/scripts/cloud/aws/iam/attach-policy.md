# attach-policy.sh

## Purpose
Attach managed IAM policies to exactly one target principal (`user`, `role`, or `group`).

## Location
`cloud/aws/iam/attach-policy.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `iam:Attach*Policy`, `iam:ListAttached*Policies`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--role NAME` | Cond. | none | Target role (exactly one of role/user/group) |
| `--user NAME` | Cond. | none | Target user |
| `--group NAME` | Cond. | none | Target group |
| `--policy-arn ARN` | Cond. | none | Managed policy ARN (repeatable) |
| `--policy-arns CSV` | Cond. | none | Comma-separated managed policy ARNs |
| `--profile PROFILE` | No | AWS default | AWS profile |
| `--if-attached` | No | `true` | Skip already attached policies |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: selected policies are attached to target principal.
- Common operational path: controlled permission expansion for app/CI identities.
- Failure path: invalid target selection or missing attach permissions.
- Recovery/rollback path: detach unintended policy via `detach-policy.sh`.

## Usage
```bash
cloud/aws/iam/attach-policy.sh --role app-runtime --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
cloud/aws/iam/attach-policy.sh --user deploy-bot --policy-arns arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess,arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess
cloud/aws/iam/attach-policy.sh --group auditors --policy-arn arn:aws:iam::aws:policy/SecurityAudit --dry-run
```

## Behavior
- Main execution flow:
  - validates single target and policy ARN set
  - checks current attachments
  - attaches only missing policies
- Idempotency notes: repeat-safe; existing attachments are skipped.
- Side effects: modifies target principal effective permissions.

## Output
- Standard output format: timestamped logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments
  - non-zero on AWS API failures

## Failure Modes
- Common errors and likely causes:
  - no or multiple target principal flags
  - malformed/nonexistent policy ARN
  - IAM access denied on attach/list APIs
- Recovery and rollback steps:
  - fix principal/policy inputs
  - verify policy existence and account partition
  - apply least required IAM privileges then rerun

## Security Notes
- Secret handling: no secret processing.
- Least-privilege requirements: tightly scope attach permissions and review approvals.
- Audit/logging expectations: policy-attach events are high-impact and should be change-controlled.

## Testing
- Unit tests:
  - target exclusivity checks and ARN validation
- Integration tests:
  - attach to user/role/group in sandbox account
- Manual verification:
  - `list-attached-*-policies` for target principal
