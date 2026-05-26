# aws-mlops-platform

Production MLOps infrastructure on AWS. This is the platform layer that data science teams build on — not the models themselves, but everything that gets models from a notebook into production reliably.

Built from running this across five data science teams at ValueLabs. The patterns here came from watching what broke when teams tried to do it themselves: experiment results that couldn't be reproduced, models deployed with no rollback path, Bedrock endpoints open to the whole VPC with no usage controls, SageMaker jobs running with admin IAM roles because nobody had set up proper execution roles.

Everything here is Terraform. No CDK, no CloudFormation. If your team already has a Terraform platform, this drops in.

---

## What this sets up

```
┌─────────────────────────────────────────────────────────────────┐
│                     aws-mlops-platform                          │
│                                                                 │
│  ┌─────────────────────┐    ┌─────────────────────────────┐    │
│  │  SageMaker Pipeline │    │   MLflow Tracking Server    │    │
│  │                     │    │                             │    │
│  │  Preprocessing  ──► │    │  Experiment tracking        │    │
│  │  Training       ──► │    │  Model registry             │    │
│  │  Evaluation     ──► │    │  Artifact store (S3)        │    │
│  │  Registration   ──► │    │  Managed or self-hosted     │    │
│  └──────────┬──────────┘    └─────────────────────────────┘    │
│             │                                                   │
│             ▼                                                   │
│  ┌─────────────────────┐    ┌─────────────────────────────┐    │
│  │   Model Registry    │    │    Bedrock Gateway          │    │
│  │                     │    │                             │    │
│  │  Approval workflow  │    │  VPC endpoint               │    │
│  │  Version tracking   │    │  IAM per-team scoping       │    │
│  │  Stage promotion    │    │  Usage guardrails           │    │
│  └──────────┬──────────┘    │  Cost allocation tags       │    │
│             │               └─────────────────────────────┘    │
│             ▼                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Model Serving on EKS                       │   │
│  │                                                         │   │
│  │  SageMaker endpoint  ──  real-time, managed scaling     │   │
│  │  EKS deployment      ──  custom serving, full control   │   │
│  │  Both behind ALB with auth                              │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Modules

| Module | What it does |
|--------|-------------|
| [sagemaker-pipeline](./modules/sagemaker-pipeline) | SageMaker Pipeline definition, execution role, artifact S3 bucket, model registry, CloudWatch logging |
| [mlflow-tracking](./modules/mlflow-tracking) | MLflow tracking server (managed or self-hosted on EKS), S3 artifact store, RDS backend for managed mode |
| [bedrock-gateway](./modules/bedrock-gateway) | Bedrock VPC endpoint, per-team IAM roles with model access scoping, usage guardrails, cost allocation |
| [model-serving-eks](./modules/model-serving-eks) | Helm chart values and IAM config for deploying model servers on EKS with IRSA |

---

## Quick start

```hcl
# SageMaker training pipeline with MLflow tracking
module "ml_pipeline" {
  source = "github.com/nitishponguluri-collab/aws-mlops-platform//modules/sagemaker-pipeline?ref=v1.0.0"

  pipeline_name        = "fraud-detection-training"
  pipeline_description = "Weekly retraining pipeline for the fraud detection model"

  create_model_registry = true
  enable_bedrock_access = false   # this pipeline doesn't use Bedrock

  artifact_retention_days = 90

  tags = {
    Team        = "data-science"
    Model       = "fraud-detection"
    Environment = "production"
  }
}

# MLflow tracking server
module "mlflow" {
  source = "github.com/nitishponguluri-collab/aws-mlops-platform//modules/mlflow-tracking?ref=v1.0.0"

  name                 = "platform-mlflow"
  use_managed_server   = true   # AWS-managed MLflow, not self-hosted
  mlflow_server_size   = "STANDARD"

  sagemaker_execution_role_arn = module.ml_pipeline.execution_role_arn

  tags = {
    Team = "platform"
  }
}

# Bedrock access for the generative AI team
module "bedrock" {
  source = "github.com/nitishponguluri-collab/aws-mlops-platform//modules/bedrock-gateway?ref=v1.0.0"

  name   = "genai-team"
  vpc_id = module.vpc.vpc_id

  allowed_models = [
    "anthropic.claude-3-5-sonnet-20241022-v2:0",
    "amazon.titan-embed-text-v2:0",
  ]

  team_role_arns = [
    "arn:aws:iam::123456789012:role/genai-team-eks-irsa",
  ]

  tags = {
    Team        = "genai"
    CostCenter  = "ai-products"
  }
}
```

See [examples/complete](./examples/complete) for all modules wired together.

---

## Design decisions worth knowing

**SageMaker execution roles are scoped, not admin.**
Every pipeline gets its own IAM role. That role has access to its artifact bucket, ECR, and CloudWatch — nothing else. Running SageMaker jobs with broad IAM roles is how you end up with a training job that can read your production database.

**MLflow artifacts go to S3, metadata goes to the managed server.**
The managed MLflow server handles the tracking API. Artifacts — model files, plots, datasets — go directly to S3 via presigned URLs. This keeps the server stateless and means losing the server doesn't lose your model files.

**Bedrock access is per-team, not per-VPC.**
One VPC endpoint for Bedrock is shared. IAM policies restrict which teams can call which models. The cost allocation tags make it possible to attribute Bedrock spend to specific teams in Cost Explorer. Without this, Bedrock spend becomes unattributable within weeks of onboarding the second team.

**Model promotion requires explicit approval.**
Models go into the registry as `PendingManualApproval`. Nothing promotes to production automatically. The approval step exists in the pipeline definition and requires a human to review evaluation metrics before the model can serve production traffic.

---

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.5.0 |
| AWS provider | ~> 5.0 |

---

## Related repos

- [aws-multi-account-landing-zone](https://github.com/nitishponguluri-collab/aws-multi-account-landing-zone) — account structure this platform runs inside
- [eks-platform-blueprint](https://github.com/nitishponguluri-collab/eks-platform-blueprint) — EKS cluster that model serving runs on
- [terraform-aws-modules](https://github.com/nitishponguluri-collab/terraform-aws-modules) — VPC, IAM, RDS modules used here

---

## License

MIT
