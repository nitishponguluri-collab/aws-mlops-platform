output "mlflow_artifact_bucket" {
  description = "S3 bucket for MLflow artifacts."
  value       = module.mlflow.artifact_bucket_name
}

output "mlflow_artifact_store_uri" {
  description = "MLflow artifact store URI — set as MLFLOW_S3_ENDPOINT_URL in training jobs."
  value       = module.mlflow.artifact_store_uri
}

output "fraud_pipeline_arn" {
  description = "ARN of the fraud detection SageMaker pipeline."
  value       = module.fraud_detection_pipeline.pipeline_arn
}

output "fraud_model_registry" {
  description = "SageMaker model registry name for fraud detection."
  value       = module.fraud_detection_pipeline.model_registry_name
}

output "bedrock_team_role_arns" {
  description = "IAM role ARNs per team — annotate EKS service accounts with these."
  value       = module.bedrock.team_role_arns
}

output "fraud_server_irsa_role_arn" {
  description = "IRSA role ARN for the fraud detection model server pod."
  value       = module.fraud_model_server.irsa_role_arn
}
