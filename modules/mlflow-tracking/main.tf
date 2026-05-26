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

# ── S3 Artifact Store ──────────────────────────────────────────────────────────
# MLflow artifacts (model files, plots, datasets) go to S3.
# The tracking server only holds metadata — artifact URIs, params, metrics.
# This means the server is stateless. Losing the server does not lose your models.

resource "aws_s3_bucket" "mlflow" {
  bucket = "${var.name}-mlflow-${data.aws_caller_identity.current.account_id}"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "mlflow" {
  bucket = aws_s3_bucket.mlflow.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mlflow" {
  bucket = aws_s3_bucket.mlflow.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "mlflow" {
  bucket                  = aws_s3_bucket.mlflow.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── IAM Role for MLflow Server ─────────────────────────────────────────────────

resource "aws_iam_role" "mlflow" {
  name = "${var.name}-mlflow-server"

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

resource "aws_iam_role_policy" "mlflow_s3" {
  name = "s3-artifact-access"
  role = aws_iam_role.mlflow.id

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
          "s3:GetBucketLocation",
        ]
        Resource = [
          aws_s3_bucket.mlflow.arn,
          "${aws_s3_bucket.mlflow.arn}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker" {
  role       = aws_iam_role.mlflow.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Allow SageMaker execution roles from other pipelines to write artifacts here.
# This is how multiple pipelines share one MLflow server.
resource "aws_iam_role_policy" "cross_role_artifact_access" {
  count = length(var.sagemaker_execution_role_arns) > 0 ? 1 : 0

  name = "cross-role-artifact-access"
  role = aws_iam_role.mlflow.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["sts:AssumeRole"]
        Resource = var.sagemaker_execution_role_arns
      }
    ]
  })
}

# ── Managed MLflow Tracking Server ────────────────────────────────────────────
# AWS-managed MLflow — no servers to run, no database to manage.
# STANDARD handles up to 20 concurrent users. Use ENHANCED for larger teams.
# If you're running MLflow on EKS yourself, set use_managed_server = false
# and point your self-hosted server at the S3 artifact bucket above.

resource "aws_sagemaker_mlflow_tracking_server" "this" {
  count = var.use_managed_server ? 1 : 0

  tracking_server_name = var.name
  artifact_store_uri   = "s3://${aws_s3_bucket.mlflow.bucket}/artifacts"
  role_arn             = aws_iam_role.mlflow.arn
  tracking_server_size = var.mlflow_server_size

  tags = var.tags
}
