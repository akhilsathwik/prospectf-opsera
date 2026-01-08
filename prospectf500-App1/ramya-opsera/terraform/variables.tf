variable "tenant" {
  description = "Tenant/organization name"
  type        = string
  default     = "adlcteam"
}

variable "app_identifier" {
  description = "Application identifier"
  type        = string
  default     = "ramya"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "deployment_name" {
  description = "Deployment name (app-opsera)"
  type        = string
  default     = "ramya-opsera"
}

