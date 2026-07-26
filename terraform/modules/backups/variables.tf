variable "bucket_name" {
  description = "Globally-unique S3 bucket name for node backups."
  type        = string
}

variable "transition_to_ia_days" {
  type    = number
  default = 30
}

variable "expire_after_days" {
  type    = number
  default = 180
}

variable "enable_lifecycle_configuration" {
  description = "Create the lifecycle rule (IA transition + expiration). Disabled in the LocalStack apply test because LocalStack Community does not converge S3 lifecycle configuration, causing the provider to poll until timeout - see terraform/environments/dev/tests/."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
