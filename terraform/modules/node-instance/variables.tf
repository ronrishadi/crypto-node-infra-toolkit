variable "name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "backup_bucket_arn" {
  description = "ARN of the S3 bucket this node is allowed to write backups to. The instance role is scoped to this bucket and nothing else."
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ami_id" {
  description = "Explicit AMI ID, bypassing the Canonical AMI lookup. Required when running against LocalStack, which does not carry a real AMI catalog; leave null against real AWS to use the latest Ubuntu 22.04 automatically."
  type        = string
  default     = null
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair. No key material is generated or stored by this module."
  type        = string
}

variable "root_volume_gb" {
  type    = number
  default = 30
}

variable "data_volume_gb" {
  description = "Size of the separate EBS volume the node's chain data lives on."
  type        = number
  default     = 200
}

variable "node_user" {
  description = "System user the node process runs as (never root)."
  type        = string
  default     = "chainnode"
}

variable "data_mount_path" {
  type    = string
  default = "/data/chain"
}

variable "metrics_namespace" {
  description = "CloudWatch namespace this instance is permitted to publish custom metrics into."
  type        = string
  default     = "CryptoNodeInfra"
}

variable "tags" {
  type    = map(string)
  default = {}
}
