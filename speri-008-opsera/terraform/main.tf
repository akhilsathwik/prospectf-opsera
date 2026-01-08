terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Use S3 backend for state persistence (Fix #75)
  # Uncomment after creating the S3 bucket
  # backend "s3" {
  #   bucket         = "speri-008-tfstate"
  #   key            = "infrastructure/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "speri-008-tfstate-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# =============================================================================
# VPC (v4.0.0: Use app_identifier for multi-user isolation)
# =============================================================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.app_identifier}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}

# =============================================================================
# EKS ArgoCD Cluster (Management Plane)
# =============================================================================
module "eks_argocd" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.app_identifier}-argocd"
  cluster_version = var.eks_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Fix #40: Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # Cluster endpoint access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Enable IRSA
  enable_irsa = true

  # ArgoCD cluster - smaller, just runs ArgoCD
  eks_managed_node_groups = {
    argocd = {
      name           = "${var.app_identifier}-argocd-ng"
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2

      labels = {
        role = "argocd-management"
      }
    }
  }

  tags = merge(var.tags, {
    role = "argocd-management"
  })
}

# =============================================================================
# EKS Workload Cluster (Workload Plane)
# =============================================================================
module "eks_workload" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.app_identifier}-workload-${var.environment}"
  cluster_version = var.eks_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Fix #40: Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # Cluster endpoint access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Enable IRSA
  enable_irsa = true

  # Workload cluster - larger, runs actual workloads
  eks_managed_node_groups = {
    workload = {
      name           = "${var.app_identifier}-workload-ng"
      instance_types = ["t3.large"]  # 35 pods per node (Fix #13)
      min_size       = 2
      max_size       = 5
      desired_size   = 2

      labels = {
        role        = "workload"
        environment = var.environment
      }
    }
  }

  tags = merge(var.tags, {
    role = "workload"
  })
}

# =============================================================================
# ECR Repositories
# =============================================================================
resource "aws_ecr_repository" "backend" {
  name                 = "${var.app_identifier}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "${var.app_identifier}-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags

  lifecycle {
    prevent_destroy = false
  }
}

# =============================================================================
# IAM Role for ExternalDNS (IRSA)
# =============================================================================
data "aws_iam_policy_document" "external_dns_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type = "Federated"
      identifiers = [
        module.eks_argocd.oidc_provider_arn,
        module.eks_workload.oidc_provider_arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks_workload.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:external-dns"]
    }
  }
}

data "aws_iam_policy_document" "external_dns" {
  statement {
    actions = [
      "route53:ChangeResourceRecordSets"
    ]
    resources = ["arn:aws:route53:::hostedzone/*"]
  }

  statement {
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "${var.app_identifier}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "external_dns" {
  name   = "${var.app_identifier}-external-dns-policy"
  role   = aws_iam_role.external_dns.id
  policy = data.aws_iam_policy_document.external_dns.json
}

# =============================================================================
# Outputs
# =============================================================================
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "argocd_cluster_name" {
  description = "ArgoCD EKS cluster name"
  value       = module.eks_argocd.cluster_name
}

output "argocd_cluster_endpoint" {
  description = "ArgoCD EKS cluster endpoint"
  value       = module.eks_argocd.cluster_endpoint
}

output "workload_cluster_name" {
  description = "Workload EKS cluster name"
  value       = module.eks_workload.cluster_name
}

output "workload_cluster_endpoint" {
  description = "Workload EKS cluster endpoint"
  value       = module.eks_workload.cluster_endpoint
}

output "ecr_backend_url" {
  description = "ECR backend repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_url" {
  description = "ECR frontend repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}

output "external_dns_role_arn" {
  description = "ExternalDNS IAM role ARN"
  value       = aws_iam_role.external_dns.arn
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = var.aws_region
}
