# create-ami.sh

## Purpose
Create an AMI from an EC2 instance with optional metadata tagging and readiness wait.

## Location
`cloud/aws/ec2/create-ami.sh`

## Preconditions
- Required tools: `bash`, `aws`, `date`, `sleep`
- Required permissions: `ec2:DescribeInstances`, `ec2:CreateImage`, `ec2:DescribeImages`, `ec2:CreateTags`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--id INSTANCE_ID` | Yes | N/A | Source instance ID |
| `--name NAME` | Yes | N/A | AMI name |
| `--description TEXT` | No | empty | AMI description |
| `--tag KEY=VALUE` | No | none | AMI tag pair (repeatable) |
| `--tags CSV` | No | none | Comma-separated AMI tag pairs |
| `--no-reboot` | No | `false` | Skip instance reboot during image creation |
| `--wait` | No | `false` | Wait until AMI state is `available` |
| `--timeout SEC` | No | `3600` | Wait timeout |
| `--poll-interval SEC` | No | `20` | Poll interval |
| `--region REGION` | No | AWS CLI default | AWS region override |
| `--profile PROFILE` | No | AWS CLI default | AWS profile override |
| `--dry-run` | No | `false` | Print commands only |

## Scenarios
- Happy path: AMI is created and reported as available.
- Common operational path: golden image creation in release pipeline with deterministic naming/tags.
- Failure path: source instance state invalid or image creation fails during snapshot pipeline.
- Recovery/rollback path: remove failed AMI artifacts and rerun with validated source instance.

## Usage
```bash
cloud/aws/ec2/create-ami.sh --id i-0123456789abcdef0 --name app-base-2026-02-27 --wait
cloud/aws/ec2/create-ami.sh --id i-0123456789abcdef0 --name app-base-rc1 --description "RC image" --tag Environment=staging
cloud/aws/ec2/create-ami.sh --id i-0123456789abcdef0 --name app-base-dryrun --dry-run
```

## Behavior
- Main execution flow:
  - validates source instance and AMI naming constraints
  - requests `create-image` (optionally no reboot)
  - applies image tags when provided
  - optionally waits for AMI to become `available`
  - prints generated `ImageId`
- Idempotency notes: AMI names should be unique; repeated runs create distinct AMIs unless naming collides.
- Side effects: new AMI and snapshots are created; storage costs increase.

## Output
- Standard output format:
  - logs on stderr
  - resulting `ImageId` on stdout
- Exit codes:
  - `0` success
  - `2` invalid arguments/preconditions
  - non-zero AWS/API/wait failures

## Failure Modes
- Common errors and likely causes:
  - invalid AMI name format
  - duplicate AMI name conflicts
  - timeout while waiting for AMI availability
- Recovery and rollback steps:
  - adjust AMI naming/versioning and rerun
  - inspect image/snapshot failure reason in EC2 console
  - deregister failed test AMIs to avoid clutter/cost

## Security Notes
- Secret handling: AMI may capture sensitive on-disk data; ensure hardening before imaging.
- Least-privilege requirements: limit image creation permissions to approved build accounts.
- Audit/logging expectations: AMI creation events should be tied to release/change records.

## Testing
- Unit tests:
  - AMI name/tag input validation
  - wait loop state handling
- Integration tests:
  - create/wait flow in non-production account
- Manual verification:
  - validate AMI state and tag set in EC2 image inventory
