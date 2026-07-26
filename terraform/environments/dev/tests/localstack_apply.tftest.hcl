# Runs the real dev root module against a LocalStack container instead of
# real AWS - actual `terraform apply`, actual resources created and torn
# down, actual assertions on the result. This is what "authored and applied
# Terraform, understands the plan/apply cycle" means to prove rather than
# claim. See ../../.github/workflows/terraform.yml for how LocalStack gets
# started before this runs.

variables {
  use_localstack     = true
  name               = "test-cryptonode"
  ssh_allowed_cidrs  = ["203.0.113.4/32"]
  ssh_key_name       = "test-key"
  backup_bucket_name = "test-cryptonode-backups-tf-test"
  # LocalStack's EC2 mock has no real Canonical AMI catalog to query, so the
  # data.aws_ami lookup is bypassed here with an arbitrary ID - LocalStack
  # accepts any AMI ID for instance creation without validating it against
  # a real catalog, since it's a mock, not a strict emulation.
  ami_id = "ami-00000000000000000"
}

run "apply_creates_expected_resources" {
  command = apply

  assert {
    condition     = output.vpc_id != ""
    error_message = "VPC was not created"
  }

  assert {
    condition     = output.node_instance_id != ""
    error_message = "Node EC2 instance was not created"
  }

  assert {
    condition     = output.backup_bucket == "test-cryptonode-backups-tf-test"
    error_message = "Backup bucket name output did not match the input variable"
  }

  assert {
    condition     = can(regex("^arn:aws:iam::", output.node_iam_role_arn))
    error_message = "Node IAM role ARN has an unexpected shape"
  }
}

run "ssh_wide_open_is_rejected" {
  command = plan

  variables {
    ssh_allowed_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [
    var.ssh_allowed_cidrs,
  ]
}
