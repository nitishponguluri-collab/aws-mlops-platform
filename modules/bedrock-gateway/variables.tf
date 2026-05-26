variable "name" {
  description = "Name prefix for all Bedrock gateway resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to create the Bedrock VPC endpoint in."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the Bedrock VPC endpoint. Use private subnets."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to reach the Bedrock VPC endpoint (EKS nodes, SageMaker)."
  type        = list(string)
  default     = []
}

variable "teams" {
  description = <<-DESC
    Map of teams and their Bedrock access config.
    Each team gets its own IAM role scoped to specific models.

    Example:
    teams = {
      genai = {
        oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/..."
        oidc_provider     = "oidc.eks.us-east-1.amazonaws.com/id/..."
        namespace         = "genai"
        service_account   = "genai-app"
        allowed_models    = ["anthropic.claude-3-5-sonnet-20241022-v2:0"]
      }
    }
  DESC
  type = map(object({
    oidc_provider_arn = string
    oidc_provider     = string
    namespace         = string
    service_account   = string
    allowed_models    = list(string)
  }))
  default = {}
}

variable "cost_alarm_threshold_usd" {
  description = "Monthly Bedrock cost threshold in USD that triggers a CloudWatch alarm. Set to 0 to disable."
  type        = number
  default     = 0
}

variable "alarm_sns_arn" {
  description = "SNS topic ARN for cost alarms. Leave empty to skip notifications."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
