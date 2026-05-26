output "vpc_endpoint_id" {
  description = "ID of the Bedrock VPC endpoint."
  value       = aws_vpc_endpoint.bedrock.id
}

output "endpoint_security_group_id" {
  description = "Security group ID attached to the Bedrock VPC endpoint."
  value       = aws_security_group.bedrock_endpoint.id
}

output "team_role_arns" {
  description = "Map of team name to IAM role ARN. Annotate EKS service accounts with these."
  value       = { for k, v in aws_iam_role.team : k => v.arn }
}
