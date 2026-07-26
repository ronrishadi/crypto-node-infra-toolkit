variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "use_localstack" {
  description = "Redirect every AWS API call to a local LocalStack endpoint instead of real AWS. Set true in CI/local testing, false (default) for anyone actually deploying this."
  type        = bool
  default     = false
}

variable "localstack_endpoint" {
  type    = string
  default = "http://localhost:4566"
}

variable "name" {
  description = "Prefix applied to every resource this stack creates."
  type        = string
  default     = "cryptonode-dev"
}

variable "availability_zone" {
  type    = string
  default = "us-east-1a"
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH into the node. Must be supplied explicitly - there is no permissive default."
  type        = list(string)

  validation {
    condition     = !contains(var.ssh_allowed_cidrs, "0.0.0.0/0")
    error_message = "ssh_allowed_cidrs must not include 0.0.0.0/0 - scope SSH access to a known operator range or bastion, not the whole internet."
  }
}

variable "ssh_key_name" {
  type = string
}

variable "backup_bucket_name" {
  description = "Globally-unique S3 bucket name for node backups."
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ami_id" {
  description = "Passed straight through to the node-instance module. Leave null against real AWS; set explicitly for LocalStack (see module docs)."
  type        = string
  default     = null
}

variable "node_ingress_ports" {
  type = list(object({
    port        = number
    description = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      port        = 26656
      description = "Tendermint/CometBFT P2P"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 26657
      description = "Tendermint/CometBFT RPC"
      cidr_blocks = ["10.20.0.0/16"] # internal only by default; widen deliberately, not by accident
    },
  ]
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "crypto-node-infra-toolkit"
    ManagedBy = "terraform"
  }
}
