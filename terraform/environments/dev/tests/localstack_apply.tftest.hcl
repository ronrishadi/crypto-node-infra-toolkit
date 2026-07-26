# Runs the real dev root module against a LocalStack container. See
# ../../../.github/workflows/ci.yml for how LocalStack gets started.
#
# Scope is deliberately split, because LocalStack Community does not emulate
# everything and pretending otherwise would make this test theatre:
#
#   - apply (real create + assert + destroy): VPC, subnet, IGW, route table,
#     security group, S3 bucket (+versioning/encryption/public-access-block),
#     and the least-privilege IAM role, policy and instance profile.
#   - plan only: the EC2 instance, its EBS data volume, the S3 lifecycle rule
#     and the CloudWatch alarms. LocalStack Community cannot serve the
#     instance-settings read the AWS provider issues after instance create,
#     and does not converge S3 lifecycle configuration, so an apply there
#     hangs rather than failing honestly. The plan run below still exercises
#     the full resource graph, provider schema, and every expression.
#
# A real-AWS apply remains the actual acceptance test before production use.

variables {
  use_localstack     = true
  name               = "test-cryptonode"
  ssh_allowed_cidrs  = ["203.0.113.4/32"]
  ssh_key_name       = "test-key"
  backup_bucket_name = "test-cryptonode-backups-tf-test"
  # LocalStack has no real AMI catalog to query, so bypass the data lookup.
  ami_id = "ami-00000000000000000"
}

# Whole-stack plan, compute included: proves the full graph resolves.
run "full_stack_plan_resolves" {
  command = plan

  assert {
    condition     = module.vpc.vpc_id != null
    error_message = "VPC did not resolve in the plan"
  }
}

# Real apply of everything LocalStack Community actually supports.
run "apply_network_storage_and_iam" {
  command = apply

  variables {
    create_compute                 = false
    enable_lifecycle_configuration = false
  }

  assert {
    condition     = output.vpc_id != ""
    error_message = "VPC was not created"
  }

  assert {
    condition     = output.node_security_group_id != ""
    error_message = "Node security group was not created"
  }

  assert {
    condition     = output.backup_bucket == "test-cryptonode-backups-tf-test"
    error_message = "Backup bucket name output did not match the input variable"
  }

  assert {
    condition     = can(regex("^arn:aws:iam::", output.node_iam_role_arn))
    error_message = "Node IAM role ARN has an unexpected shape"
  }

  # create_compute = false must genuinely skip compute, not silently create it.
  assert {
    condition     = output.node_instance_id == null
    error_message = "Instance was created despite create_compute = false"
  }

  assert {
    condition     = output.alerts_topic_arn == null
    error_message = "Monitoring was created despite create_compute = false"
  }
}

# Guardrail: a wide-open SSH rule must be rejected by variable validation
# before it ever reaches a plan.
run "ssh_wide_open_is_rejected" {
  command = plan

  variables {
    ssh_allowed_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [
    var.ssh_allowed_cidrs,
  ]
}
