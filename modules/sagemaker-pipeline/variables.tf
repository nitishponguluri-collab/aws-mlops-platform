variable "pipeline_name" {
  description = "Name of the SageMaker pipeline. Also used to name the artifact bucket, IAM role, and model registry."
  type        = string
}

variable "pipeline_display_name" {
  description = "Human-readable display name. Defaults to pipeline_name."
  type        = string
  default     = ""
}

variable "pipeline_description" {
  description = "Description of what this pipeline does."
  type        = string
  default     = ""
}

variable "pipeline_definition" {
  description = "JSON pipeline definition. Pass in the full pipeline JSON here."
  type        = string
  default     = <<-JSON
    {
      "Version": "2020-12-01",
      "Metadata": {},
      "Parameters": [],
      "Steps": []
    }
  JSON
}

variable "artifact_retention_days" {
  description = "Days to retain pipeline run artifacts before expiry. Model artifacts in /models/ are not affected."
  type        = number
  default     = 90
}

variable "create_model_registry" {
  description = "Whether to create a SageMaker Model Package Group for this pipeline."
  type        = bool
  default     = true
}

variable "enable_bedrock_access" {
  description = "Attach a policy allowing the execution role to invoke Bedrock foundation models."
  type        = bool
  default     = false
}

variable "additional_policy_arns" {
  description = "Additional IAM policy ARNs to attach to the execution role."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
