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

variable "tags" {
  type    = map(string)
  default = {}
}
