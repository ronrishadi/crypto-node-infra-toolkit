# LocalStack's EC2 mock does not carry a real Canonical AMI catalog, so the
# `data.aws_ami` lookup below only runs against real AWS. Tests (and any
# other LocalStack run) pass ami_id explicitly instead - see
# terraform/environments/dev/tests/localstack_apply.tftest.hcl.
data "aws_ami" "ubuntu" {
  count       = var.create_instance && var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

locals {
  ami_id = var.ami_id != null ? var.ami_id : one(data.aws_ami.ubuntu[*].id)
}

# Least-privilege instance role: this instance can write its own backups to
# exactly one bucket and publish its own CloudWatch metrics. It cannot read
# or list any other bucket, cannot touch IAM, and cannot assume any other
# role. Broadening this policy is the kind of change that should get a
# second pair of eyes in review, not something to do by reflex.
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "node_permissions" {
  statement {
    sid     = "BackupUploadOnly"
    actions = ["s3:PutObject", "s3:GetObject"]
    resources = [
      "${var.backup_bucket_arn}/${var.name}/*",
    ]
  }

  statement {
    sid       = "ListOwnPrefixOnly"
    actions   = ["s3:ListBucket"]
    resources = [var.backup_bucket_arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.name}/*"]
    }
  }

  statement {
    sid       = "SelfMetricsOnly"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"] # PutMetricData has no resource-level ARN; scoped by namespace condition below.
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = [var.metrics_namespace]
    }
  }
}

resource "aws_iam_role_policy" "node" {
  name   = "${var.name}-node-policy"
  role   = aws_iam_role.node.id
  policy = data.aws_iam_policy_document.node_permissions.json
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.name}-node-profile"
  role = aws_iam_role.node.name
}

resource "aws_instance" "node" {
  count                  = var.create_instance ? 1 : 0
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.node.name
  key_name               = var.ssh_key_name

  # Root volume for the OS; chain data lives on the separate volume below so
  # OS reinstalls never risk node state, and the two can be sized/backed up
  # independently.
  root_block_device {
    volume_size = var.root_volume_gb
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens   = "required" # IMDSv2 only - IMDSv1 is a known SSRF-to-credential-theft vector.
    http_endpoint = "enabled"
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    node_user  = var.node_user
    data_mount = var.data_mount_path
  })

  tags = merge(var.tags, { Name = "${var.name}-node" })
}

resource "aws_ebs_volume" "chain_data" {
  count             = var.create_instance ? 1 : 0
  availability_zone = aws_instance.node[0].availability_zone
  size              = var.data_volume_gb
  type              = "gp3"
  encrypted         = true
  tags              = merge(var.tags, { Name = "${var.name}-chain-data" })
}

resource "aws_volume_attachment" "chain_data" {
  count       = var.create_instance ? 1 : 0
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.chain_data[0].id
  instance_id = aws_instance.node[0].id
}
