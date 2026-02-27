# resize-instance.sh

## Purpose
Safely resize an EC2 instance type using controlled stop-modify-start workflow.

## Location
`cloud/aws/ec2/resize-instance.sh`

## Preconditions
- Required tools: `bash`, `aws`, `date`, `sleep`
- Required permissions: `ec2:DescribeInstances`, `ec2:StopInstances`, `ec2:ModifyInstanceAttribute`, `ec2:StartInstances`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--id INSTANCE_ID` | Yes | N/A | Target instance ID |
| `--instance-type TYPE` | Yes | N/A | Destination instance type (e.g. `m6i.large`) |
| `--region REGION` | No | AWS CLI default | AWS region override |
| `--profile PROFILE` | No | AWS CLI default | AWS profile override |
| `--allow-stop` | No | `false` | Required to resize running instances |
| `--start-after` | No | `auto` | Force start after resize |
| `--no-start-after` | No | `auto` | Keep stopped after resize |
| `--wait` | No | `true` | Wait for state transitions |
| `--no-wait` | No | `false` | Do not wait for state transitions |
| `--timeout SEC` | No | `1200` | Wait timeout |
| `--poll-interval SEC` | No | `15` | Poll interval |
| `--dry-run` | No | `false` | Print commands only |

## Scenarios
- Happy path: running instance is stopped, resized, restarted, and returns to `running`.
- Common operational path: scheduled right-sizing with explicit approval to stop workloads.
- Failure path: running instance without `--allow-stop`, invalid type, or blocked modify call.
- Recovery/rollback path: revert to previous type and restart using same workflow if needed.

## Usage
```bash
cloud/aws/ec2/resize-instance.sh --id i-0123456789abcdef0 --instance-type m6i.large --allow-stop
cloud/aws/ec2/resize-instance.sh --id i-0123456789abcdef0 --instance-type c7i.xlarge --allow-stop --no-start-after
cloud/aws/ec2/resize-instance.sh --id i-0123456789abcdef0 --instance-type m6i.large --dry-run
```

## Behavior
- Main execution flow:
  - validates instance/type inputs and current state
  - enforces explicit stop permission for running instances
  - stops instance if needed, modifies instance type, then optionally restarts
  - waits for state transitions when enabled
- Idempotency notes: no-op if current type already matches target.
- Side effects: planned instance downtime and compute shape change.

## Output
- Standard output format: timestamped lifecycle logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments/precondition failures
  - non-zero AWS/API/wait failures

## Failure Modes
- Common errors and likely causes:
  - unsupported/invalid target type for region or architecture
  - modify permission denied
  - timeout on stop/start transition
- Recovery and rollback steps:
  - validate type availability and IAM scope
  - rerun with previous type if rollback is required
  - inspect EC2 instance events for transition blockers

## Security Notes
- Secret handling: none.
- Least-privilege requirements: limit modify/start/stop permissions to approved instance scopes.
- Audit/logging expectations: resizing actions should map to capacity and change-management approvals.

## Testing
- Unit tests:
  - argument/precondition validation
  - start-after mode selection logic
- Integration tests:
  - resize workflow for stopped and running instances
- Manual verification:
  - confirm `InstanceType` change and final `State.Name`
