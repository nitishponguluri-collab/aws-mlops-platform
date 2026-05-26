variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "platform_name" {
  type    = string
  default = "ml-platform"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "eks_node_security_group_id" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider" {
  type = string
}

variable "alarm_sns_arn" {
  type    = string
  default = ""
}
