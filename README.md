# Crypto Node Infrastructure Toolkit

[![ci](https://github.com/ronrishadi/crypto-node-infra-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/ronrishadi/crypto-node-infra-toolkit/actions/workflows/ci.yml)

Terraform + Bash + systemd for running a blockchain node in production:
provision the AWS side (VPC, EC2, least-privilege IAM, S3 backups,
CloudWatch alarms), then operate the Linux side (systemd hardening, health
checks, log analysis, backups) once it's running.

This exists to demonstrate real, tested infrastructure work - not to claim
years of professional ops experience that don't exist yet. Everything here
either runs and is tested in CI, or is explicitly marked as a design
decision with the reasoning behind it.

## Safety boundary

- No real AWS account, credentials, or spend anywhere in this repo or its
  CI. Every `terraform apply` in CI targets a disposable
  [LocalStack](https://www.localstack.cloud/) container, not real AWS.
- No blockchain node binary is included or run for real. `chaind` in the
  systemd unit is a placeholder for whatever the actual node software is -
  the unit, its hardening, and the operational tooling around it are the
  real subject matter.
- No live funds, validator keys, or seed material anywhere in this repo.

## What's actually verified, and how

| Claim | Where it's proven |
| --- | --- |
| Terraform authored and applied, understands state/plan/apply | `terraform test` in CI runs a real `apply` against LocalStack for the VPC / security group / S3 / IAM layer, asserts on the live outputs, then destroys it - plus a whole-stack `plan` run. Exact scope split below. See `terraform/environments/dev/tests/localstack_apply.tftest.hcl` |
| AWS: EC2, VPC, IAM, S3, CloudWatch | One module each, wired together in `terraform/environments/dev/main.tf`. VPC, S3, and IAM are apply-tested for real; EC2 and CloudWatch are plan-tested only (LocalStack Community limitation, see below) |
| Terraform variable validation, not just happy-path code | A dedicated test asserts that `ssh_allowed_cidrs = ["0.0.0.0/0"]` is **rejected** at plan time, not just discouraged in a comment |
| Linux administration: systemd, package mgmt, log analysis | `systemd/chainnode.service` (hardened unit), `scripts/bootstrap-node.sh` (idempotent setup), `scripts/log-analyze.sh` (log triage) |
| Bash scripting for automation/diagnostics | `scripts/node-healthcheck.sh`, `scripts/backup-to-s3.sh` - both covered by `bats` tests that mock `systemctl`/`curl`/`df`/`aws`/`journalctl` rather than requiring a real node to test against |
| Credential and access hygiene | IAM policy scoped to one S3 prefix and one CloudWatch namespace (see below), IMDSv2-only, encrypted EBS/S3, no secrets in code, `.gitignore` excludes `*.tfvars`/state |
| Git workflow | Real commit history, CI on every push, `.terraform.lock.hcl` committed per Terraform convention |

## What is apply-tested vs plan-tested, precisely

I'd rather state this exactly than let "tested against LocalStack" imply
more than it does.

**Real `apply` + assert + `destroy` in CI** (LocalStack Community emulates
these well enough to be meaningful): VPC, public subnet, internet gateway,
route table + association, node security group, S3 backup bucket with
versioning / SSE / public-access-block, and the least-privilege IAM role,
policy document and instance profile.

**`plan` only:** the EC2 instance, its encrypted EBS data volume, the S3
lifecycle rule, and the CloudWatch alarms + SNS topic. LocalStack Community
cannot serve the instance-settings read the AWS provider issues immediately
after instance creation, and does not converge S3 lifecycle configuration -
in both cases an `apply` hangs until timeout rather than failing cleanly, so
asserting on it would be theatre. The plan run still exercises the complete
resource graph, the real provider schema, and every expression and
interpolation in the stack.

This split is why `create_compute` and `enable_lifecycle_configuration`
exist as variables. Both default to `true`; the LocalStack test sets them
`false`. A real-AWS apply is still the actual acceptance test before
production use, and I have not run one.

## Least privilege, concretely

The node's IAM role (`terraform/modules/node-instance/main.tf`) can:

- `s3:PutObject`/`GetObject` under `s3://<bucket>/<node-name>/*` only - not
  the whole bucket, not any other bucket.
- `cloudwatch:PutMetricData` scoped to one namespace via a policy
  condition.

It cannot list any other prefix, touch IAM, or assume any other role. If a
future change needs to broaden this, that's the kind of diff that should
get read carefully in review, not merged by reflex - which is exactly why
it's this narrow to start with.

## Architecture

```text
terraform/
  modules/
    vpc/            VPC, public subnet, IGW, route table, node security group
    node-instance/   EC2 node, least-privilege IAM role, encrypted EBS data volume
    backups/         S3 bucket: versioned, encrypted, public-access-blocked, lifecycle-managed
    monitoring/       CloudWatch alarms (CPU, disk) + SNS topic
  environments/dev/   root module wiring the above; LocalStack toggle via use_localstack
    tests/             terraform test suite, runs against LocalStack in CI

scripts/
  bootstrap-node.sh    idempotent host setup: user, data dir, systemd unit, logrotate
  node-healthcheck.sh  service/RPC/disk/log checks; exit 0=healthy 1=degraded 2=down
  log-analyze.sh       error/warning triage over any log stream
  backup-to-s3.sh      tar + upload + local-retention pruning, with a real --dry-run
  tests/               bats-core suite - 22 tests, all mocking external commands via PATH

systemd/
  chainnode.service    hardened unit: NoNewPrivileges, ProtectSystem=strict,
                        dedicated user, resource limits, restart policy
```

## Running the Terraform locally against LocalStack

```bash
docker run -d -p 4566:4566 localstack/localstack:3

cd terraform/environments/dev
terraform init -backend=false
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 \
  terraform test
```

Or against real AWS: copy `terraform.tfvars.example` to `terraform.tfvars`,
fill in your own values (a real SSH CIDR - never `0.0.0.0/0` - and an
existing key pair name), and run the normal `terraform plan`/`apply` with
`use_localstack` left at its default `false`.

## Running the scripts locally

```bash
sudo apt-get install -y bats shellcheck   # or: brew install bats-core shellcheck
shellcheck scripts/*.sh
bats scripts/tests/
```

## Honest limitations

- LocalStack Community is not a byte-for-byte AWS emulation. See the
  apply-vs-plan section above for exactly which resources are created for
  real in CI and which are only planned. A real-AWS `apply` is the actual
  acceptance test before production use, and has not been run.
- The systemd unit's `ExecStart` targets a placeholder `chaind` binary -
  swap it for whatever the real node software is before use.
- No autoscaling, no multi-AZ failover, no automated node-restore-from-backup
  path yet - this covers one node's provisioning and day-2 operations, not
  a full fleet.
