variable "name" {
  description = "Name for the model server — used in IAM role names and CloudWatch resources."
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN for IRSA."
  type        = string
}

variable "oidc_provider" {
  description = "EKS OIDC provider URL without https:// prefix."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace the model server runs in."
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes service account name to bind the IAM role to."
  type        = string
}

variable "model_artifact_bucket_arns" {
  description = "S3 bucket ARNs containing model artifacts the server needs to read."
  type        = list(string)
}

variable "create_serving_alarms" {
  description = "Create CloudWatch alarms for model serving latency and error rate."
  type        = bool
  default     = true
}

variable "p99_latency_threshold_ms" {
  description = "P99 inference latency in milliseconds that triggers an alarm."
  type        = number
  default     = 1000
}

variable "error_rate_threshold_pct" {
  description = "Inference error rate percentage that triggers an alarm."
  type        = number
  default     = 5
}

variable "alarm_sns_arn" {
  description = "SNS topic ARN for serving alarms."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
