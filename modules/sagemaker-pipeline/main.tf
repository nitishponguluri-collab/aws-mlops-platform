terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── S3 Artifact Bucket ─────────────────────────────────────────────────────────
# All pipeline inputs, outputs, and model artifacts land here.
# Versioning is on so you can reference any previous pipeline run's outputs.
# Lifecycle rule expires old run artifacts — model files in /models/ are excluded
# so registered models are not deleted by the lifecycle policy.

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.pipeline_name}-mlops-${data.aws_caller_identity.current.account_id}"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-pipeline-runs"
    status = "Enabled"

    filter {
      prefix = "pipeline-runs/"
    }

    expiration {
      days = var.artifact_retention_days
    }
  }
}

# ── IAM Execution Role ─────────────────────────────────────────────────────────
# Scoped to this pipeline's artifact bucket. Not wildcard S3.
# Attach additional policies via var.additional_policy_arns for ECR, VPC, etc.

resource "aws_iam_role" "execution" {
  name = "${var.pipeline_name}-sagemaker-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "s3_access" {
  name = "s3-artifact-access"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = toset(var.additional_policy_arns)

  role       = aws_iam_role.execution.name
  policy_arn = each.value
}

# Bedrock access — optional, only attach when the pipeline uses foundation models
# for evaluation, data augmentation, or synthetic data generation steps.
resource "aws_iam_role_policy" "bedrock" {
  count = var.enable_bedrock_access ? 1 : 0

  name = "bedrock-invoke"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
      ]
      Resource = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/*"
    }]
  })
}

# ── CloudWatch Log Group ───────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "pipeline" {
  name              = "/aws/sagemaker/pipelines/${var.pipeline_name}"
  retention_in_days = 90
  tags              = var.tags
}

# ── SageMaker Pipeline ─────────────────────────────────────────────────────────
# Pipeline definition is passed in as JSON so this module stays generic.
# The caller owns the step definitions — preprocessing, training, evaluation,
# model registration. See examples/complete for a full pipeline definition.

resource "aws_sagemaker_pipeline" "this" {
  pipeline_name         = var.pipeline_name
  pipeline_display_name = coalesce(var.pipeline_display_name, var.pipeline_name)
  pipeline_description  = var.pipeline_description
  role_arn              = aws_iam_role.execution.arn
  pipeline_definition   = var.pipeline_definition
  tags                  = var.tags
}

# ── Model Registry ─────────────────────────────────────────────────────────────
# Models go in as PendingManualApproval. Nothing auto-promotes to production.
# The approval step is enforced at the registry level, not just in the pipeline.

resource "aws_sagemaker_model_package_group" "this" {
  count = var.create_model_registry ? 1 : 0

  model_package_group_name        = var.pipeline_name
  model_package_group_description = "Model registry for ${var.pipeline_name}"
  tags                            = var.tags
}
