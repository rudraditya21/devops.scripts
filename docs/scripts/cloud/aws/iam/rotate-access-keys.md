# rotate-access-keys.sh

## Purpose
Rotate IAM user access keys safely and emit new credentials in machine-consumable formats.

## Location
`cloud/aws/iam/rotate-access-keys.sh`

## Preconditions
- Required tools: `bash`, `aws`
- Required permissions: `iam:ListAccessKeys`, `iam:CreateAccessKey`, optional `iam:UpdateAccessKey`, `iam:DeleteAccessKey`, `iam:GetUser`
- Required environment variables: none

## Arguments
| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--user NAME` | Yes | N/A | IAM user to rotate |
| `--profile PROFILE` | No | AWS default | AWS profile |
| `--deactivate-old-keys` | No | `false` | Deactivate pre-existing active keys after create |
| `--delete-inactive-keys` | No | `false` | Delete inactive keys to free slots and clean up |
| `--output MODE` | No | `env` | `env\|json\|table` |
| `--yes` | Cond. | `false` | Required for deactivation/deletion actions |
| `--dry-run` | No | `false` | Print planned commands |

## Scenarios
- Happy path: new key created, old keys deactivated/deleted based on policy.
- Common operational path: periodic access-key rotation in secrets management pipelines.
- Failure path: user already at key limit without eligible inactive key cleanup.
- Recovery/rollback path: reactivate prior key or re-run with proper cleanup flags.

## Usage
```bash
cloud/aws/iam/rotate-access-keys.sh --user ci-bot --output json
cloud/aws/iam/rotate-access-keys.sh --user deploy-bot --deactivate-old-keys --delete-inactive-keys --yes
cloud/aws/iam/rotate-access-keys.sh --user backup-bot --delete-inactive-keys --yes --dry-run
```

## Behavior
- Main execution flow:
  - validates user and key inventory state
  - optionally deletes inactive key to free AWS key slot limit
  - creates new access key
  - optionally deactivates old active keys
  - optionally removes inactive keys
  - emits new credential material
- Idempotency notes: key creation is intentionally non-idempotent; cleanup actions are convergent with flags.
- Side effects: IAM key lifecycle changes and credential issuance.

## Output
- Standard output format:
  - logs on stderr
  - newly created credentials on stdout (`env`, `json`, or `table`)
- Exit codes:
  - `0` success
  - `2` invalid input/safety guard failure
  - non-zero on AWS API failures

## Failure Modes
- Common errors and likely causes:
  - key slot exhaustion (2 keys) with no deletable inactive key
  - missing `--yes` when destructive key-state changes requested
  - IAM denies key lifecycle actions
- Recovery and rollback steps:
  - delete/deactivate obsolete keys and rerun
  - confirm new key is stored/propagated before deactivation
  - reactivate prior key if immediate rollback is needed

## Security Notes
- Secret handling: script outputs `SecretAccessKey` once; capture securely and never log/plaintext commit it.
- Least-privilege requirements: restrict key-management permissions to dedicated automation roles.
- Audit/logging expectations: key rotation events must be auditable and linked to credential governance policies.

## Testing
- Unit tests:
  - key-slot logic and safety confirmation checks
- Integration tests:
  - rotate users with different key states in sandbox account
- Manual verification:
  - `list-access-keys` plus downstream auth validation with new key
