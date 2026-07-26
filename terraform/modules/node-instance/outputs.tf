output "instance_id" {
  description = "Null when create_instance = false (LocalStack apply test)."
  value       = one(aws_instance.node[*].id)
}

output "private_ip" {
  description = "Null when create_instance = false."
  value       = one(aws_instance.node[*].private_ip)
}

output "iam_role_arn" {
  description = "Always created, regardless of create_instance - the least-privilege policy is the part worth testing for real."
  value       = aws_iam_role.node.arn
}
