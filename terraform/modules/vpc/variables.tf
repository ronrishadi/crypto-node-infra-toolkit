variable "name" {
  description = "Prefix applied to every resource name/tag created by this module."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the single public subnet the node instance lives in."
  type        = string
  default     = "10.20.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the public subnet."
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to reach port 22. Never default this to 0.0.0.0/0."
  type        = list(string)

  validation {
    condition     = !contains(var.ssh_allowed_cidrs, "0.0.0.0/0")
    error_message = "ssh_allowed_cidrs must not include 0.0.0.0/0 - scope SSH access to a known operator range or bastion, not the whole internet."
  }
}

variable "node_ingress_ports" {
  description = "Additional TCP ports to open on the node security group (P2P, RPC, etc), each with its own allowed CIDR list."
  type = list(object({
    port        = number
    description = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Common tags applied to every resource."
  type        = map(string)
  default     = {}
}
