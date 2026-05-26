terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── SageMaker Training Pipeline ────────────────────────────────────────────────
module "fraud_detection_pipeline" {
  source = "../../modules/sagemaker-pipeline"

  pipeline_name        = "fraud-detection-training"
  pipeline_description = "Weekly retraining pipeline for fraud detection model"

  create_model_registry = true
  enable_bedrock_access = false
  artifact_retention_days = 90

  tags = local.tags
}

# ── MLflow Tracking Server ─────────────────────────────────────────────────────
module "mlflow" {
  source = "../../modules/mlflow-tracking"

  name               = "${var.platform_name}-mlflow"
  use_managed_server = true
  mlflow_server_size = "STANDARD"

  sagemaker_execution_role_arns = [
    module.fraud_detection_pipeline.execution_role_arn,
  ]

  tags = local.tags
}

# ── Bedrock Gateway ────────────────────────────────────────────────────────────
module "bedrock" {
  source = "../../modules/bedrock-gateway"

  name       = var.platform_name
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  allowed_security_group_ids = [var.eks_node_security_group_id]

  teams = {
    genai = {
      oidc_provider_arn = var.oidc_provider_arn
      oidc_provider     = var.oidc_provider
      namespace         = "genai"
      service_account   = "genai-app"
      allowed_models = [
        "anthropic.claude-3-5-sonnet-20241022-v2:0",
        "amazon.titan-embed-text-v2:0",
      ]
    }
  }

  cost_alarm_threshold_usd = 500
  alarm_sns_arn            = var.alarm_sns_arn

  tags = local.tags
}

# ── Model Serving on EKS ───────────────────────────────────────────────────────
module "fraud_model_server" {
  source = "../../modules/model-serving-eks"

  name                 = "fraud-detection"
  oidc_provider_arn    = var.oidc_provider_arn
  oidc_provider        = var.oidc_provider
  namespace            = "ml-serving"
  service_account_name = "fraud-detection-server"

  model_artifact_bucket_arns = [
    module.fraud_detection_pipeline.artifact_bucket_arn,
  ]

  create_serving_alarms    = true
  p99_latency_threshold_ms = 500
  error_rate_threshold_pct = 2
  alarm_sns_arn            = var.alarm_sns_arn

  tags = local.tags
}

locals {
  tags = {
    Platform    = var.platform_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
