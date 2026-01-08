terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Use S3 backend for state persistence (Fix #75)
  backend "s3" {
    bucket         = "prospectf500-app1-tfstate"
    key            = "infrastructure/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "prospectf500-app1-tfstate-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      tenant         = var.tenant
      app-identifier = var.app_identifier
      environment    = var.environment
      managed-by     = "opsera-gitops"
      created-by     = "claude-code"
    }
  }
}

# Get AWS Account ID
data "aws_caller_identity" "current" {}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================================================
# VPC (v4.0.0: Use app-identifier for multi-user isolation)
# ============================================================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.app_identifier}-vpc"
  cidr = "10.0.0.0/16"

  azs             = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.app_identifier}-vpc"
  }
}

# ============================================================================
# ECR Repositories
# ============================================================================
resource "aws_ecr_repository" "backend" {
  name                 = "${var.app_identifier}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.app_identifier}-backend"
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "${var.app_identifier}-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.app_identifier}-frontend"
  }
}

# ============================================================================
# ArgoCD Cluster (Management Plane) - v4.0.0: Use app-identifier
# ============================================================================
module "argocd_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  # Keep cluster name short to avoid IAM role name_prefix > 38 chars
  # Example: prospectf500-app1-cd
  cluster_name    = "${var.app_identifier}-cd"
  cluster_version = var.cluster_version
  # Avoid long IAM role name_prefix (Fix: keep under 38 chars)
  iam_role_use_name_prefix = false

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Fix #40: Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # Cluster endpoint access - enable public for GitHub Actions
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Enable IRSA for ExternalDNS
  enable_irsa = true

  # ArgoCD cluster - smaller, just runs ArgoCD
  eks_managed_node_groups = {
    argocd = {
      instance_types = ["t3.medium"]
      min_size       = var.node_min_size
      max_size       = 3
      desired_size   = var.node_min_size
    }
  }

  tags = {
    Name = "${var.app_identifier}-argocd"
    role = "argocd-management"
  }
}

# ============================================================================
# Workload Cluster (Target Plane) - v4.0.0: Use app-identifier
# ============================================================================
module "workload_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  # Keep cluster name short to satisfy IAM role name_prefix <= 38 chars
  # Example: prospectf500-app1-wrk-dev
  cluster_name    = "${var.app_identifier}-wrk-${var.environment}"
  cluster_version = var.cluster_version
  # Avoid long IAM role name_prefix (Fix: keep under 38 chars)
  iam_role_use_name_prefix = false

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Fix #40: Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # Cluster endpoint access - enable public for GitHub Actions
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Enable IRSA for ExternalDNS, AWS LB Controller
  enable_irsa = true

  # Workload cluster - larger, runs actual workloads
  eks_managed_node_groups = {
    workload = {
      instance_types = [var.node_instance_type]
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
    }
  }

  tags = {
    Name        = "${var.app_identifier}-wrk-${var.environment}"
    role        = "workload"
    environment = var.environment
  }
}

# ============================================================================
# Note: ECR Permissions
# ============================================================================
# The terraform-aws-modules/eks module automatically attaches 
# AmazonEC2ContainerRegistryReadOnly policy to node group IAM roles.
# No additional configuration needed.

# ============================================================================
# ExternalDNS IAM Role (for workload cluster)
# ============================================================================
resource "aws_iam_role" "external_dns" {
  name = "${var.app_identifier}-external-dns"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.workload_cluster.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.workload_cluster.oidc_provider_arn}:sub" = "system:serviceaccount:kube-system:external-dns"
            "${module.workload_cluster.oidc_provider_arn}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.app_identifier}-external-dns"
  }
}

resource "aws_iam_role_policy" "external_dns" {
  name = "${var.app_identifier}-external-dns-policy"
  role = aws_iam_role.external_dns.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:GetChange"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# Outputs
# ============================================================================
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "argocd_cluster_name" {
  description = "ArgoCD cluster name"
  value       = module.argocd_cluster.cluster_name
}

output "workload_cluster_name" {
  description = "Workload cluster name"
  value       = module.workload_cluster.cluster_name
}

output "argocd_cluster_endpoint" {
  description = "ArgoCD cluster endpoint"
  value       = module.argocd_cluster.cluster_endpoint
}

output "workload_cluster_endpoint" {
  description = "Workload cluster endpoint"
  value       = module.workload_cluster.cluster_endpoint
}

output "ecr_backend_repository_url" {
  description = "ECR backend repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repository_url" {
  description = "ECR frontend repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}

output "external_dns_role_arn" {
  description = "ExternalDNS IAM role ARN"
  value       = aws_iam_role.external_dns.arn
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for workload cluster"
  value       = module.workload_cluster.oidc_provider_arn
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = var.aws_region
}
