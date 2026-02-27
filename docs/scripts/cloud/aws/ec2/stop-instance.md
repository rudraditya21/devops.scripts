# stop-instance.sh

## Purpose
Stop EC2 instances with optional force/hibernate controls and configurable wait behavior.

## Location
`cloud/aws/ec2/stop-instance.sh`

## Preconditions
- Required tools: `bash`, `aws`, `date`, `sleep`
- Required permissions: `ec2:DescribeInstances`, `ec2:StopInstances`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--id INSTANCE_ID` | Cond. | none | Instance ID (repeatable) |
| `--ids CSV` | Cond. | none | Comma-separated instance IDs |
| `--region REGION` | No | AWS CLI default | AWS region override |
| `--profile PROFILE` | No | AWS CLI default | AWS profile override |
| `--force` | No | `false` | Force stop when graceful shutdown fails |
| `--hibernate` | No | `false` | Request hibernation-capable stop |
| `--wait` | No | `true` | Wait for `stopped` state |
| `--no-wait` | No | `false` | Return immediately after stop API call |
| `--timeout SEC` | No | `900` | Wait timeout |
| `--poll-interval SEC` | No | `10` | Poll interval during wait |
| `--dry-run` | No | `false` | Print commands only |

## Scenarios
- Happy path: running instances stop and reach `stopped` state.
- Common operational path: maintenance window shutdown with optional hibernate.
- Failure path: unsupported state transition or IAM denies stop action.
- Recovery/rollback path: review target states, clear blockers, and retry with explicit flags.

## Usage
```bash
cloud/aws/ec2/stop-instance.sh --id i-0123456789abcdef0
cloud/aws/ec2/stop-instance.sh --ids i-0123456789abcdef0,i-0fedcba9876543210 --force
cloud/aws/ec2/stop-instance.sh --id i-0123456789abcdef0 --hibernate --no-wait
```

## Behavior
- Main execution flow:
  - validates IDs and current states
  - skips already stopped/stopping instances
  - issues stop request with optional force/hibernate modifiers
  - optionally waits for convergence to `stopped`
- Idempotency notes: repeat-safe for already stopped targets.
- Side effects: compute shutdown; potential in-memory state preservation with hibernate.

## Output
- Standard output format: timestamped lifecycle logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments/state preconditions
  - non-zero AWS CLI/API failure codes

## Failure Modes
- Common errors and likely causes:
  - hibernate not supported for instance configuration
  - forced stop required for hung shutdown path
  - timeout while waiting for state transition
- Recovery and rollback steps:
  - retry with `--force` if operationally approved
  - validate hibernate prerequisites (instance family, AMI, EBS settings)
  - inspect EC2 events for stop blockers

## Security Notes
- Secret handling: none.
- Least-privilege requirements: scoped stop/describe permissions.
- Audit/logging expectations: stop operations should be covered by operational approval records.

## Testing
- Unit tests:
  - flag parsing (`--force`, `--hibernate`, wait controls)
  - state handling and target selection
- Integration tests:
  - stop running instances with and without wait
- Manual verification:
  - confirm `State.Name=stopped` and stop timestamps
