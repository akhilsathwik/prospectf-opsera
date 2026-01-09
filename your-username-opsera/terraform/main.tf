terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration will be provided via -backend-config flags
  # S3 backend is created by GitHub Actions workflow
  backend "s3" {
    # bucket, key, region, dynamodb_table provided via -backend-config
  }
}

provider "aws" {
  region = var.app_region
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get default VPC (or create new one)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Local values for resource naming
locals {
  argocd_cluster_name = "argocd-${var.app_region}"
  workload_cluster_name = "${var.tenant_name}-${var.app_region}-${var.cluster_env}"
  ecr_repo_backend = "${var.tenant_name}/${var.app_name}-backend"
  ecr_repo_frontend = "${var.tenant_name}/${var.app_name}-frontend"
  aws_account_id = data.aws_caller_identity.current.account_id
  ecr_registry = "${local.aws_account_id}.dkr.ecr.${var.app_region}.amazonaws.com"
}

# ========================================
# ECR REPOSITORIES
# ========================================
resource "aws_ecr_repository" "backend" {
  name                 = local.ecr_repo_backend
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = local.ecr_repo_backend
    Tenant      = var.tenant_name
    Application = var.app_name
    Environment = var.app_env
    ManagedBy   = "Terraform"
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = local.ecr_repo_frontend
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = local.ecr_repo_frontend
    Tenant      = var.tenant_name
    Application = var.app_name
    Environment = var.app_env
    ManagedBy   = "Terraform"
  }
}

# ========================================
# EKS CLUSTER - ArgoCD (Shared per region)
# ========================================
resource "aws_eks_cluster" "argocd" {
  name     = local.argocd_cluster_name
  role_arn = aws_iam_role.argocd_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = data.aws_subnets.default.ids
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.argocd_cluster_AmazonEKSClusterPolicy,
    aws_cloudwatch_log_group.argocd_cluster,
  ]

  tags = {
    Name      = local.argocd_cluster_name
    Purpose   = "ArgoCD"
    ManagedBy = "Terraform"
    Shared    = "true"
  }
}

resource "aws_cloudwatch_log_group" "argocd_cluster" {
  name              = "/aws/eks/${local.argocd_cluster_name}/cluster"
  retention_in_days = 7
}

# ========================================
# EKS CLUSTER - Workload (Tenant-specific)
# ========================================
resource "aws_eks_cluster" "workload" {
  name     = local.workload_cluster_name
  role_arn = aws_iam_role.workload_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = data.aws_subnets.default.ids
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.workload_cluster_AmazonEKSClusterPolicy,
    aws_cloudwatch_log_group.workload_cluster,
  ]

  tags = {
    Name        = local.workload_cluster_name
    Tenant      = var.tenant_name
    Environment = var.cluster_env
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "workload_cluster" {
  name              = "/aws/eks/${local.workload_cluster_name}/cluster"
  retention_in_days = 7
}

# ========================================
# EKS NODE GROUPS
# ========================================
resource "aws_eks_node_group" "argocd" {
  cluster_name    = aws_eks_cluster.argocd.name
  node_group_name = "argocd-nodes"
  node_role_arn   = aws_iam_role.argocd_nodes.arn
  subnet_ids      = data.aws_subnets.default.ids

  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.argocd_nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.argocd_nodes_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.argocd_nodes_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = {
    Name = "argocd-nodes"
  }
}

resource "aws_eks_node_group" "workload" {
  cluster_name    = aws_eks_cluster.workload.name
  node_group_name = "workload-nodes"
  node_role_arn   = aws_iam_role.workload_nodes.arn
  subnet_ids      = data.aws_subnets.default.ids

  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.workload_nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.workload_nodes_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.workload_nodes_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = {
    Name = "workload-nodes"
  }
}

# ========================================
# IAM ROLES - ArgoCD Cluster
# ========================================
resource "aws_iam_role" "argocd_cluster" {
  name = "${local.argocd_cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "argocd_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.argocd_cluster.name
}

resource "aws_iam_role" "argocd_nodes" {
  name = "${local.argocd_cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "argocd_nodes_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.argocd_nodes.name
}

resource "aws_iam_role_policy_attachment" "argocd_nodes_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.argocd_nodes.name
}

resource "aws_iam_role_policy_attachment" "argocd_nodes_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.argocd_nodes.name
}

# ========================================
# IAM ROLES - Workload Cluster
# ========================================
resource "aws_iam_role" "workload_cluster" {
  name = "${local.workload_cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "workload_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.workload_cluster.name
}

resource "aws_iam_role" "workload_nodes" {
  name = "${local.workload_cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "workload_nodes_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.workload_nodes.name
}

resource "aws_iam_role_policy_attachment" "workload_nodes_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.workload_nodes.name
}

resource "aws_iam_role_policy_attachment" "workload_nodes_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.workload_nodes.name
}

# ========================================
# OUTPUTS
# ========================================
output "argocd_cluster_name" {
  description = "ArgoCD EKS cluster name"
  value       = aws_eks_cluster.argocd.name
}

output "argocd_cluster_endpoint" {
  description = "ArgoCD EKS cluster endpoint"
  value       = aws_eks_cluster.argocd.endpoint
}

output "workload_cluster_name" {
  description = "Workload EKS cluster name"
  value       = aws_eks_cluster.workload.name
}

output "workload_cluster_endpoint" {
  description = "Workload EKS cluster endpoint"
  value       = aws_eks_cluster.workload.endpoint
}

output "ecr_repo_backend" {
  description = "ECR repository URL for backend"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_repo_frontend" {
  description = "ECR repository URL for frontend"
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecr_registry" {
  description = "ECR registry URL"
  value       = local.ecr_registry
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = local.aws_account_id
}
