output "vpc_id" {
  value = module.vpc.vpc_id
}

output "node_instance_id" {
  value = module.node.instance_id
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
  value = module.monitoring.alerts_topic_arn
}
