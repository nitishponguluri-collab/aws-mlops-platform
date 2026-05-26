output "pipeline_arn" {
  description = "ARN of the SageMaker pipeline."
  value       = aws_sagemaker_pipeline.this.arn
}

output "execution_role_arn" {
  description = "ARN of the SageMaker execution IAM role."
  value       = aws_iam_role.execution.arn
}

output "execution_role_name" {
  description = "Name of the SageMaker execution IAM role."
  value       = aws_iam_role.execution.name
}

output "artifact_bucket_name" {
  description = "Name of the S3 artifact bucket."
  value       = aws_s3_bucket.artifacts.bucket
}

output "artifact_bucket_arn" {
  description = "ARN of the S3 artifact bucket."
  value       = aws_s3_bucket.artifacts.arn
}

output "model_registry_name" {
  description = "Name of the SageMaker model package group."
  value       = var.create_model_registry ? aws_sagemaker_model_package_group.this[0].model_package_group_name : ""
}

output "log_group_name" {
  description = "CloudWatch log group for pipeline execution logs."
  value       = aws_cloudwatch_log_group.pipeline.name
}
