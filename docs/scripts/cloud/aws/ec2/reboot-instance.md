# reboot-instance.sh

## Purpose
Reboot running EC2 instances and optionally wait until system and instance checks return `ok`.

## Location
`cloud/aws/ec2/reboot-instance.sh`

## Preconditions
- Required tools: `bash`, `aws`, `date`, `sleep`
- Required permissions: `ec2:DescribeInstances`, `ec2:DescribeInstanceStatus`, `ec2:RebootInstances`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--id INSTANCE_ID` | Cond. | none | Instance ID (repeatable) |
| `--ids CSV` | Cond. | none | Comma-separated instance IDs |
| `--region REGION` | No | AWS CLI default | AWS region override |
| `--profile PROFILE` | No | AWS CLI default | AWS profile override |
| `--wait` | No | `true` | Wait for status checks to pass |
| `--no-wait` | No | `false` | Return immediately after reboot API call |
| `--timeout SEC` | No | `1200` | Wait timeout |
| `--poll-interval SEC` | No | `15` | Poll interval during wait |
| `--dry-run` | No | `false` | Print commands only |

## Scenarios
- Happy path: running instance reboots and health checks recover to `ok`.
- Common operational path: service-level remediation before deeper repair actions.
- Failure path: target instance not in running state or status checks stay degraded.
- Recovery/rollback path: escalate to stop/start or replacement if reboot does not recover health.

## Usage
```bash
cloud/aws/ec2/reboot-instance.sh --id i-0123456789abcdef0
cloud/aws/ec2/reboot-instance.sh --ids i-0123456789abcdef0,i-0fedcba9876543210 --no-wait
cloud/aws/ec2/reboot-instance.sh --id i-0123456789abcdef0 --timeout 1800 --poll-interval 20
```

## Behavior
- Main execution flow:
  - validates running-state precondition for each target
  - issues reboot request
  - optionally polls instance/system status checks until all are `ok`
- Idempotency notes: reboot is inherently mutating but safe for repeated execution under incident control.
- Side effects: transient service interruption during restart cycle.

## Output
- Standard output format: timestamped operational logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments/state preconditions
  - non-zero on AWS/API or wait timeout failures

## Failure Modes
- Common errors and likely causes:
  - reboot requested for non-running instance
  - prolonged degraded instance/system checks
  - insufficient reboot permissions
- Recovery and rollback steps:
  - verify state and permissions, then retry
  - escalate to stop/start or restore procedures if checks remain unhealthy

## Security Notes
- Secret handling: none.
- Least-privilege requirements: reboot and describe permissions on allowed instances only.
- Audit/logging expectations: reboot actions should be tied to incident/change tracking.

## Testing
- Unit tests:
  - ID parsing and state validation
  - wait timeout/poll logic
- Integration tests:
  - reboot path and status-check convergence in test account
- Manual verification:
  - confirm `InstanceStatus.Status=ok` and `SystemStatus.Status=ok`
