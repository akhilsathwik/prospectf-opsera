# Unified AWS EKS Deployment Guide

## Overview

This repository now includes a **unified AWS EKS container deployment workflow** following the Opsera v1.13.0 pattern. The deployment includes infrastructure provisioning, application building, and automated verification.

## Configuration Summary

Based on auto-detected values from your existing deployment:

| Input | Value |
|-------|-------|
| **Tenant Name** | `opsera-se` |
| **Application Name** | `prospectf500-app1` |
| **Environment** | `dev` |
| **AWS Region** | `eu-north-1` |

## Resource Names (Short Convention)

| Resource | Name | Notes |
|----------|------|-------|
| **VPC** | `opsera-vpc` | Shared across all deployments |
| **ArgoCD Cluster** | `argocd-eun1` | Short region code: eu-north-1 → eun1 |
| **Workload Cluster** | `opsera-se-eun1-np` | np = nonprod (dev/staging) |
| **ECR Repository** | `opsera-se/prospectf500-app1` | Lowercase enforced |
| **Namespace** | `prospectf500-app1-dev` | Auto-derived |
| **Branch** | `prospectf500-app1-deploy` | Created and ready |

## Files Created

### 1. GitHub Actions Workflow
**Location**: `.github/workflows/deploy-unified.yaml`

**Features**:
- **Phase 1: Infrastructure** - Discovers/creates VPC, EKS clusters, ECR repos
- **Phase 2: Application** - Builds and pushes Docker images
- **Phase 3: Verification** - Verifies infrastructure status
- Brownfield detection (reuses existing infrastructure)
- Short naming conventions (Learning #118)
- Region-specific Terraform state buckets (Learning #114)

### 2. Kubernetes Manifests
**Location**: `k8s-unified/`

**Structure**:
```
k8s-unified/
├── base/
│   ├── namespace.yaml
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   └── kustomization.yaml
└── overlays/
    └── dev/
        └── kustomization.yaml
```

**Features**:
- ExternalDNS annotations for automatic DNS record creation
- NLB (Network Load Balancer) configuration
- HTTPS support with ACM certificate annotations
- AWS credentials secret fallback for IRSA (Learning #139)
- Health probes configured

### 3. ArgoCD Application
**Location**: `argocd-unified/application.yaml`

**Note**: Update the `repoURL` field with your actual GitHub repository URL before deploying.

### 4. Deployment Summary Template
**Location**: `templates/deployment-summary.html`

Visual HTML dashboard showing:
- Cloud architecture diagram
- Code-to-cloud journey timeline
- Phase metrics
- Security scores
- Environment promotion options

## How to Deploy

### Prerequisites

1. **GitHub Secrets** (Required):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

2. **AWS Permissions**:
   - EKS cluster creation
   - ECR repository creation
   - VPC creation
   - Route53 DNS management (for ExternalDNS)

### Step 1: Update ArgoCD Application

Edit `argocd-unified/application.yaml` and update:
```yaml
source:
  repoURL: https://github.com/YOUR_ORG/YOUR_REPO.git  # ← Update this
  targetRevision: prospectf500-app1-deploy
```

### Step 2: Push Branch to GitHub

```bash
git push origin prospectf500-app1-deploy
```

### Step 3: Trigger Workflow

1. Go to GitHub Actions tab
2. Select "Deploy to AWS EKS (Unified)" workflow
3. Click "Run workflow"
4. Use default values (or modify if needed):
   - Tenant: `opsera-se`
   - App Name: `prospectf500-app1`
   - Environment: `dev`
   - Region: `eu-north-1`

### Step 4: Monitor Deployment

The workflow will:
1. **Discover Infrastructure** (2-3 minutes)
   - Checks for existing VPC, clusters, ECR repos
   - Determines deployment type (greenfield/brownfield)

2. **Create Infrastructure** (if needed, 15-30 minutes)
   - VPC with public/private subnets
   - ArgoCD EKS cluster
   - Workload EKS cluster
   - ECR repositories
   - Node groups

3. **Build & Push Images** (5-10 minutes)
   - Builds backend and frontend Docker images
   - Pushes to ECR with SHA and `latest` tags

4. **Verify Deployment** (2-5 minutes)
   - Checks cluster status
   - Generates deployment summary

## Deployment Types

### Greenfield (New Infrastructure)
- Creates VPC, ArgoCD cluster, Workload cluster
- Installs ArgoCD
- **Duration**: ~30-45 minutes

### Brownfield (Existing Infrastructure)
- Reuses existing VPC and clusters
- Only creates missing resources
- **Duration**: ~5-10 minutes

## Endpoints

After successful deployment:

- **LoadBalancer URL**: Available immediately after service creation
- **DNS Endpoint**: `https://prospectf500-app1-dev.agents.opsera-labs.com`
  - Requires ExternalDNS to create Route53 record (1-2 minutes)
  - Requires ACM certificate validation (5-30 minutes)

## Troubleshooting

### Common Issues

1. **Workflow uses old version**
   - **Fix**: Trigger from `main` branch: `gh workflow run "Deploy to AWS EKS (Unified)" --ref main`

2. **Terraform S3 301 redirect**
   - **Fix**: Already handled with region-specific bucket names

3. **Image pull errors**
   - **Fix**: Check ECR repository exists and node group has ECR read permissions

4. **LoadBalancer stuck in Pending**
   - **Fix**: Check node group has ELB permissions (already included in workflow)

5. **DNS not resolving**
   - **Fix**: ExternalDNS may take 1-2 minutes. Check ExternalDNS pod logs in `kube-system` namespace

## Next Steps

1. **Review Workflow**: Check `.github/workflows/deploy-unified.yaml` for any customizations
2. **Update ArgoCD App**: Set correct repository URL in `argocd-unified/application.yaml`
3. **Push Branch**: `git push origin prospectf500-app1-deploy`
4. **Trigger Deployment**: Use GitHub Actions UI or CLI
5. **Monitor**: Watch workflow execution in GitHub Actions

## Learnings Applied

This deployment incorporates **124 verified fixes** including:

- **#118**: Short naming conventions
- **#134**: Dual image tagging (SHA + latest)
- **#135**: HTTPS with ACM certificates
- **#138-143**: IRSA fallback with AWS credentials secret
- **#144**: Context auto-detection
- **#145**: App name alignment with K8s service name

## Support

For issues or questions:
1. Check workflow logs in GitHub Actions
2. Review troubleshooting section above
3. Check cluster status: `aws eks describe-cluster --name <cluster-name> --region eu-north-1`

---

**Deployment Ready**: ✅ All files created and committed to `prospectf500-app1-deploy` branch
