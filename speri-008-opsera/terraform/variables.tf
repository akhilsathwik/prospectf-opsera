variable "tenant" {
  description = "Tenant/organization name"
  type        = string
  default     = "speri"
}

variable "app_identifier" {
  description = "Application identifier"
  type        = string
  default     = "speri-008"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "eks_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.29"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    tenant          = "speri"
    app-identifier  = "speri-008"
    environment     = "dev"
    deployment-name = "speri-008-opsera"
    managed-by      = "opsera-gitops"
    created-by      = "claude-code"
  }
}
