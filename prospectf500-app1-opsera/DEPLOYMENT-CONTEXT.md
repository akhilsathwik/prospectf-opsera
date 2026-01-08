# Deployment Context

## Identifiers
- **Tenant**: opsera-se
- **App Identifier**: prospectf500-app1
- **Environment**: dev
- **Branch/Folder**: prospectf500-app1-opsera
- **ArgoCD Folder**: prospectf500-app1-opsera/argocd/

## GitOps Architecture
- **Pattern**: greenfield
- **ArgoCD**: CREATE NEW
- **Workload Cluster**: CREATE NEW

## Resource Names
- **ArgoCD App**: prospectf500-app1-argo-dev
- **Namespace**: prospectf500-app1-dev
- **ECR Backend**: prospectf500-app1-backend
- **ECR Frontend**: prospectf500-app1-frontend
- **VPC**: prospectf500-app1-vpc
- **ArgoCD Cluster**: prospectf500-app1-argocd
- **Workload Cluster**: prospectf500-app1-workload-dev

## AWS Configuration
- **Region**: eu-north-1 (used for EKS, ECR, and ACM - keep consistent!)
- **Account ID**: [Will be detected during deployment]
- **EKS Cluster**: prospectf500-app1-argocd / prospectf500-app1-workload-dev

## Resource Tags (apply to ALL cloud resources)
```
app-identifier: prospectf500-app1
environment: dev
deployment-name: prospectf500-app1-opsera
gitops-pattern: greenfield
managed-by: opsera-gitops
created-by: claude-code
tenant: opsera-se
```

## Endpoints (after deployment)
- **URL**: https://prospectf500-app1-dev.agents.opsera-labs.com

## Pattern-Specific Checklist

### greenfield Pattern Steps:
- [ ] Create ArgoCD management cluster (Terraform)
- [ ] Create workload cluster (Terraform)
- [ ] Install ArgoCD on management cluster
- [ ] Register workload cluster with ArgoCD
- [ ] Install ExternalDNS on workload cluster

## Common Steps (All Patterns):
- [ ] Branch created
- [ ] Folder structure created
- [ ] Initial commit pushed
- [ ] ECR repositories created (tagged)
- [ ] Namespace created (labeled)
- [ ] ArgoCD application created: prospectf500-app1-argo-dev
- [ ] Deployment verified

---
Created: 2026-01-08T14:30:00Z
