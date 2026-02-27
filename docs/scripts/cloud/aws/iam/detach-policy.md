# detach-policy.sh

## Purpose
Detach managed IAM policies from one target principal (`user`, `role`, or `group`).

## Location
`cloud/aws/iam/detach-policy.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `iam:Detach*Policy`, `iam:ListAttached*Policies`
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
| `--if-missing` | No | `false` | Skip detach when not attached |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: selected policies are detached from principal.
- Common operational path: post-migration permission cleanup.
- Failure path: policy not attached (without `--if-missing`) or missing detach permissions.
- Recovery/rollback path: reattach policy with `attach-policy.sh` if detachment was unintended.

## Usage
```bash
cloud/aws/iam/detach-policy.sh --role app-runtime --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
cloud/aws/iam/detach-policy.sh --user deploy-bot --policy-arns arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --if-missing
cloud/aws/iam/detach-policy.sh --group auditors --policy-arn arn:aws:iam::aws:policy/SecurityAudit --dry-run
```

## Behavior
- Main execution flow:
  - validates target and policy ARNs
  - verifies attachment state per policy
  - detaches attached policies
- Idempotency notes: use `--if-missing` for convergent detach behavior.
- Side effects: reduces target principal permissions.

## Output
- Standard output format: timestamped logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid input or missing-attachment guard failures
  - non-zero on AWS API failures

## Failure Modes
- Common errors and likely causes:
  - detached policy not present on target
  - target selection ambiguity
  - denied detach/list privileges
- Recovery and rollback steps:
  - enable `--if-missing` for idempotent workflows
  - correct target/policy inputs and rerun
  - reattach required policy if removed accidentally

## Security Notes
- Secret handling: none.
- Least-privilege requirements: restrict detach permissions to approved admin roles.
- Audit/logging expectations: permission-reduction events should be documented in change records.

## Testing
- Unit tests:
  - attachment-state checks and option parsing
- Integration tests:
  - detach from each principal type in test account
- Manual verification:
  - validate reduced policy set via list-attached APIs
