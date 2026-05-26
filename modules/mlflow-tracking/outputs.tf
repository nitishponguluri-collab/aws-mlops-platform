output "artifact_bucket_name" {
  description = "S3 bucket name for MLflow artifacts."
  value       = aws_s3_bucket.mlflow.bucket
}

output "artifact_bucket_arn" {
  description = "S3 bucket ARN for MLflow artifacts."
  value       = aws_s3_bucket.mlflow.arn
}

output "artifact_store_uri" {
  description = "MLflow artifact store URI — pass this to your training jobs as MLFLOW_S3_ENDPOINT_URL."
  value       = "s3://${aws_s3_bucket.mlflow.bucket}/artifacts"
}

output "mlflow_server_arn" {
  description = "ARN of the managed MLflow tracking server. Empty if use_managed_server is false."
  value       = var.use_managed_server ? aws_sagemaker_mlflow_tracking_server.this[0].arn : ""
}

output "mlflow_role_arn" {
  description = "IAM role ARN for the MLflow server."
  value       = aws_iam_role.mlflow.arn
}
