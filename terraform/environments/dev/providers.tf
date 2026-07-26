terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# When use_localstack = true (set by CI, see ../../../.github/workflows/terraform.yml)
# every AWS API call is redirected to a local LocalStack container instead
# of real AWS - same Terraform code, same resource graph, zero cloud spend
# and zero real credentials. This is what "authored and applied Terraform,
# understand the plan/apply cycle" means to demonstrate honestly without an
# AWS bill: the code is real, the target is a sandboxed emulator.
provider "aws" {
  region = var.aws_region

  access_key                  = var.use_localstack ? "test" : null
  secret_key                  = var.use_localstack ? "test" : null
  s3_use_path_style           = var.use_localstack
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      ec2        = var.localstack_endpoint
      iam        = var.localstack_endpoint
      s3         = var.localstack_endpoint
      sts        = var.localstack_endpoint
      cloudwatch = var.localstack_endpoint
      sns        = var.localstack_endpoint
    }
  }
}
