variable "name" {
  description = "Name prefix for all MLflow resources."
  type        = string
}

variable "use_managed_server" {
  description = "Use AWS-managed MLflow tracking server. Set to false if running MLflow on EKS yourself."
  type        = bool
  default     = true
}

variable "mlflow_server_size" {
  description = "Managed MLflow server size. STANDARD = up to 20 concurrent users. ENHANCED = larger teams."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "ENHANCED"], var.mlflow_server_size)
    error_message = "mlflow_server_size must be STANDARD or ENHANCED."
  }
}

variable "sagemaker_execution_role_arns" {
  description = "SageMaker execution role ARNs from other pipelines that need to write artifacts to this MLflow server."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
