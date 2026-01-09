variable "tenant_name" {
  description = "Tenant/Organization name"
  type        = string
  default     = "opsera-se"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "your-username"
}

variable "app_env" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "app_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-north-1"
}

variable "cluster_env" {
  description = "Cluster environment (prod or nonprod)"
  type        = string
  default     = "nonprod"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.26"
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}
