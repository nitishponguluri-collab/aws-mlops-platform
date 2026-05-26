output "irsa_role_arn" {
  description = "IAM role ARN to annotate on the Kubernetes service account."
  value       = aws_iam_role.model_server.arn
}

output "irsa_role_name" {
  description = "IAM role name."
  value       = aws_iam_role.model_server.name
}

output "log_group_name" {
  description = "CloudWatch log group for model serving logs."
  value       = aws_cloudwatch_log_group.model_server.name
}
