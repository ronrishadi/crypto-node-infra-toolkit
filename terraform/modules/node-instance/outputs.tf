output "instance_id" {
  value = aws_instance.node.id
}

output "private_ip" {
  value = aws_instance.node.private_ip
}

output "iam_role_arn" {
  value = aws_iam_role.node.arn
}
