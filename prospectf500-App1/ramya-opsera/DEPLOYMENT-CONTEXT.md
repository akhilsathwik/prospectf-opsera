# Deployment Context

## Identifiers
- **Tenant**: adlcteam
- **App Identifier**: ramya
- **Environment**: dev
- **Branch/Folder**: ramya-opsera (ramya-opsera)
- **ArgoCD Folder**: ramya-opsera/argocd/

## GitOps Architecture
- **Pattern**: greenfield
- **ArgoCD**: CREATE NEW
- **Workload Cluster**: CREATE NEW

## Resource Names
- **ArgoCD App**: ramya-argo-dev
- **Namespace**: ramya-dev
- **ECR Backend**: ramya-backend
- **ECR Frontend**: ramya-frontend

## AWS Configuration
- **Region**: us-east-1 (used for EKS, ECR, and ACM - keep consistent!)
- **Account ID**: (configure AWS credentials to get account ID)
- **EKS Cluster**: adlcteam-argocd / adlcteam-workload-dev

## Resource Tags (apply to ALL cloud resources)
```
app-identifier: ramya
environment: dev
deployment-name: ramya-opsera
gitops-pattern: greenfield
managed-by: opsera-gitops
created-by: claude-code
```

## Endpoints (after deployment)
- **URL**: https://ramya-dev.agents.opsera-labs.com

## Pattern-Specific Checklist

### greenfield Pattern Steps:
- [ ] Create ArgoCD management cluster (Terraform)
- [ ] Create workload cluster (Terraform)
- [ ] Install ArgoCD on management cluster
- [ ] Register workload cluster with ArgoCD
- [ ] Install ExternalDNS on workload cluster

## Common Steps (All Patterns):
- [x] Branch created
- [x] Folder structure created
- [ ] Initial commit pushed
- [ ] ECR repositories created (tagged)
- [ ] Namespace created (labeled)
- [ ] ArgoCD application created: ramya-argo-dev
- [ ] Deployment verified

---
Created: 2026-01-06T12:00:00Z

