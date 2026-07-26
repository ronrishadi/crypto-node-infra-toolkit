output "vpc_id" {
  value = module.vpc.vpc_id
}

output "node_security_group_id" {
  value = module.vpc.node_security_group_id
}

output "node_instance_id" {
  description = "Null when create_compute = false."
  value       = module.node.instance_id
}

output "node_private_ip" {
  value = module.node.private_ip
}

output "node_iam_role_arn" {
  value = module.node.iam_role_arn
}

output "backup_bucket" {
  value = module.backups.bucket_name
}

output "alerts_topic_arn" {
  description = "Null when create_compute = false."
  value       = one(module.monitoring[*].alerts_topic_arn)
}
