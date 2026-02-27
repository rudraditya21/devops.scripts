# create-role.sh

## Purpose
Create IAM roles from a trust policy file, with optional tags and managed policy attachments.

## Location
`cloud/aws/iam/create-role.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `iam:CreateRole`, optional `iam:TagRole`, `iam:AttachRolePolicy`, `iam:GetRole`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--role-name NAME` | Yes | N/A | IAM role name |
| `--trust-policy-file PATH` | Yes | N/A | Trust policy JSON file |
| `--description TEXT` | No | empty | Role description |
| `--path PATH` | No | `/` | IAM path |
| `--max-session-duration SEC` | No | `3600` | Max session duration (`3600..43200`) |
| `--tag KEY=VALUE` | No | none | Tag pair (repeatable) |
| `--tags CSV` | No | none | Comma-separated tag pairs |
| `--attach-policy-arn ARN` | No | none | Managed policy ARN (repeatable) |
| `--attach-policy-arns CSV` | No | none | Comma-separated policy ARNs |
| `--if-not-exists` | No | `false` | Skip create if role exists |
| `--profile PROFILE` | No | AWS default | AWS profile |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: role is created and required managed policies are attached.
- Common operational path: bootstrap service roles during environment provisioning.
- Failure path: invalid trust policy file, duplicate role, or permission denial.
- Recovery/rollback path: detach policies/delete role if incorrect, then rerun with fixed inputs.

## Usage
```bash
cloud/aws/iam/create-role.sh --role-name app-runtime --trust-policy-file iam/trust.json
cloud/aws/iam/create-role.sh --role-name ci-runner --trust-policy-file iam/ci-trust.json --attach-policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
cloud/aws/iam/create-role.sh --role-name app-runtime --trust-policy-file iam/trust.json --if-not-exists --dry-run
```

## Behavior
- Main execution flow:
  - validates role name/trust policy file
  - checks whether role already exists
  - creates role when needed
  - idempotently attaches missing managed policies
- Idempotency notes: role creation is idempotent with `--if-not-exists`; policy attachments skip existing ones.
- Side effects: creates/updates IAM role metadata and policy attachments.

## Output
- Standard output format: timestamped logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid input or guarded failure
  - non-zero on AWS API errors

## Failure Modes
- Common errors and likely causes:
  - malformed/invalid trust policy JSON
  - role already exists without `--if-not-exists`
  - missing IAM create/attach permissions
- Recovery and rollback steps:
  - validate trust policy with `aws iam simulate-custom-policy`/JSON checks
  - use `--if-not-exists` for convergent provisioning
  - apply required IAM privileges and retry

## Security Notes
- Secret handling: no secrets stored; trust policy file may include sensitive principals and should be controlled.
- Least-privilege requirements: only role management actions required.
- Audit/logging expectations: role creation/attachment events should map to change tickets and CloudTrail.

## Testing
- Unit tests:
  - role/tag/policy input validation
  - idempotent attachment logic
- Integration tests:
  - create role with/without existing role paths
- Manual verification:
  - `aws iam get-role` and `list-attached-role-policies`
