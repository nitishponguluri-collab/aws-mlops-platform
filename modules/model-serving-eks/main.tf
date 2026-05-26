terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

data "aws_region" "current" {}

# ── IRSA Role for Model Server ─────────────────────────────────────────────────
# The model server pod needs to read model artifacts from S3 and optionally
# call SageMaker endpoints or Bedrock. This role provides exactly that — nothing more.

resource "aws_iam_role" "model_server" {
  name = "${var.name}-model-server"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "model_artifacts" {
  name = "model-artifact-read"
  role = aws_iam_role.model_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = flatten([
          for bucket_arn in var.model_artifact_bucket_arns : [
            bucket_arn,
            "${bucket_arn}/*",
          ]
        ])
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudwatch" {
  name = "cloudwatch-metrics"
  role = aws_iam_role.model_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudwatch:PutMetricData",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "*"
    }]
  })
}

# ── CloudWatch Alarms for Model Serving ────────────────────────────────────────
# P99 latency and error rate are the two metrics that matter for a model server.
# If p99 latency is spiking, the model is overloaded or the input distribution shifted.
# If error rate climbs, the model is returning invalid outputs or crashing under load.

resource "aws_cloudwatch_metric_alarm" "p99_latency" {
  count = var.create_serving_alarms ? 1 : 0

  alarm_name          = "${var.name}-model-server-p99-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "p99_inference_latency_ms"
  namespace           = "MLPlatform/${var.name}"
  period              = 60
  extended_statistic  = "p99"
  threshold           = var.p99_latency_threshold_ms
  alarm_description   = "Model server p99 latency exceeded ${var.p99_latency_threshold_ms}ms"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "error_rate" {
  count = var.create_serving_alarms ? 1 : 0

  alarm_name          = "${var.name}-model-server-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "inference_error_rate"
  namespace           = "MLPlatform/${var.name}"
  period              = 60
  statistic           = "Average"
  threshold           = var.error_rate_threshold_pct
  alarm_description   = "Model server error rate exceeded ${var.error_rate_threshold_pct}%"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}

# ── CloudWatch Log Group ───────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "model_server" {
  name              = "/mlplatform/${var.name}/serving"
  retention_in_days = 30
  tags              = var.tags
}
