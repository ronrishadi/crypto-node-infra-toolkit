variable "name" {
  type = string
}

variable "instance_id" {
  type = string
}

variable "metrics_namespace" {
  type    = string
  default = "CryptoNodeInfra"
}

variable "cpu_alarm_threshold" {
  type    = number
  default = 85
}

variable "disk_alarm_threshold" {
  type    = number
  default = 80
}

variable "tags" {
  type    = map(string)
  default = {}
}
