# start-instance.sh

## Purpose
Start one or more EC2 instances safely with optional state convergence waiting.

## Location
`cloud/aws/ec2/start-instance.sh`

## Preconditions
- Required tools: `bash`, `aws`, `date`, `sleep`
- Required permissions: `ec2:DescribeInstances`, `ec2:StartInstances`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--id INSTANCE_ID` | Cond. | none | Instance ID (repeatable) |
| `--ids CSV` | Cond. | none | Comma-separated instance IDs |
| `--region REGION` | No | AWS CLI default | AWS region override |
| `--profile PROFILE` | No | AWS CLI default | AWS profile override |
| `--wait` | No | `true` | Wait for `running` state |
| `--no-wait` | No | `false` | Return immediately after start API call |
| `--timeout SEC` | No | `900` | Wait timeout |
| `--poll-interval SEC` | No | `10` | Poll interval during wait |
| `--dry-run` | No | `false` | Print commands only |

## Scenarios
- Happy path: stopped instances start and reach `running` before script exits.
- Common operational path: start several patch-window instances by explicit IDs.
- Failure path: target instance in invalid state or missing start permission.
- Recovery/rollback path: inspect state transitions in CloudTrail/EC2 console and retry failed IDs.

## Usage
```bash
cloud/aws/ec2/start-instance.sh --id i-0123456789abcdef0
cloud/aws/ec2/start-instance.sh --ids i-0123456789abcdef0,i-0fedcba9876543210 --no-wait
cloud/aws/ec2/start-instance.sh --id i-0123456789abcdef0 --timeout 1200 --poll-interval 15
```

## Behavior
- Main execution flow:
  - validates IDs and fetches current states
  - skips already running/pending instances
  - starts eligible targets
  - optionally waits until all requested instances are `running`
- Idempotency notes: safe repeat execution; already-running instances are skipped.
- Side effects: changes instance power state.

## Output
- Standard output format: timestamped lifecycle logs on stderr.
- Exit codes:
  - `0` success
  - `2` invalid arguments/state preconditions
  - non-zero AWS CLI/API failure codes

## Failure Modes
- Common errors and likely causes:
  - invalid instance ID input
  - unauthorized `StartInstances`
  - timeout waiting for long boot cycles
- Recovery and rollback steps:
  - verify IAM policy and account/region context
  - increase timeout for heavy boot workloads
  - inspect failed instance status checks and system logs

## Security Notes
- Secret handling: no secret output or persistence.
- Least-privilege requirements: start + describe permissions for scoped instances only.
- Audit/logging expectations: instance starts should align with approved change windows.

## Testing
- Unit tests:
  - option parsing and ID validation
  - state skip/start target selection
- Integration tests:
  - start stopped instances in non-production account
  - wait/no-wait behavior
- Manual verification:
  - confirm `State.Name=running` via `describe-instances`
