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
data "aws_caller_identity" "current" {}

# ── VPC Endpoint for Bedrock ───────────────────────────────────────────────────
# One VPC endpoint shared across all teams. Traffic to Bedrock stays on the
# AWS network — no public internet exposure even if a pod's egress is open.
# Interface endpoint — you pay per hour and per GB processed.

resource "aws_vpc_endpoint" "bedrock" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.bedrock_endpoint.id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.name}-bedrock-endpoint" })
}

resource "aws_security_group" "bedrock_endpoint" {
  name        = "${var.name}-bedrock-endpoint"
  description = "Allow HTTPS from EKS nodes and SageMaker to Bedrock VPC endpoint"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from allowed security groups"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-bedrock-endpoint" })
}

# ── Per-team IAM Roles ─────────────────────────────────────────────────────────
# Each team gets its own IAM role scoped to specific models.
# Teams assume these roles via IRSA (EKS) or SageMaker execution role chaining.
# Bedrock spend is attributable per team via cost allocation tags on API calls.
#
# Why per-team roles instead of one shared role:
# Without this, one team burning through Claude Sonnet calls makes it impossible
# to know which team is responsible when the Bedrock bill spikes.

resource "aws_iam_role" "team" {
  for_each = var.teams

  name = "${var.name}-bedrock-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # IRSA — EKS pods assume this role via service account annotation
      {
        Effect = "Allow"
        Principal = {
          Federated = each.value.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${each.value.oidc_provider}:sub" = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, { Team = each.key })
}

resource "aws_iam_role_policy" "team_bedrock" {
  for_each = var.teams

  name = "bedrock-model-access"
  role = aws_iam_role.team[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
        ]
        Resource = [
          for model_id in each.value.allowed_models :
          "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${model_id}"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/Team" = each.key
          }
        }
      }
    ]
  })
}

# ── CloudWatch Usage Alarms ────────────────────────────────────────────────────
# Alert when a team's Bedrock spend exceeds the monthly threshold.
# Uses estimated charges metric — not perfect but catches runaway usage.

resource "aws_cloudwatch_metric_alarm" "bedrock_cost" {
  for_each = var.cost_alarm_threshold_usd > 0 ? var.teams : {}

  alarm_name          = "${var.name}-bedrock-${each.key}-cost-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 86400 # daily
  statistic           = "Maximum"
  threshold           = var.cost_alarm_threshold_usd
  alarm_description   = "Bedrock estimated charges for ${each.key} team exceeded $${var.cost_alarm_threshold_usd}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = "AmazonBedrock"
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = merge(var.tags, { Team = each.key })
}
