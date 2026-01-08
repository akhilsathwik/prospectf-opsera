# Deployment Context

## Identifiers
- **Tenant**: speri
- **App Identifier**: speri-008
- **Environment**: dev
- **Branch/Folder**: speri-008-opsera
- **ArgoCD Folder**: speri-008-opsera/argocd/

## GitOps Architecture
- **Pattern**: GREENFIELD
- **ArgoCD**: CREATE NEW (speri-008-argocd cluster)
- **Workload Cluster**: CREATE NEW (speri-008-workload-dev cluster)

## Resource Names
- **ArgoCD App**: speri-008-argo-dev
- **Namespace**: speri-008-dev
- **ECR Backend**: speri-008-backend
- **ECR Frontend**: speri-008-frontend

## AWS Configuration
- **Region**: us-east-1 (used for EKS, ECR, and ACM - keep consistent!)
- **Account ID**: 792373136340
- **VPC**: speri-008-vpc
- **ArgoCD Cluster**: speri-008-argocd
- **Workload Cluster**: speri-008-workload-dev

## Resource Tags (apply to ALL cloud resources)
```
tenant: speri
app-identifier: speri-008
environment: dev
deployment-name: speri-008-opsera
managed-by: opsera-gitops
created-by: claude-code
```

## Endpoints (after deployment)
- **URL**: https://speri-008-dev.agents.opsera-labs.com

## GREENFIELD Pattern Steps:
- [ ] Run infrastructure workflow (creates VPC, EKS clusters, ECR repos)
- [ ] Install ArgoCD on management cluster
- [ ] Install ExternalDNS on workload cluster
- [ ] Register workload cluster with ArgoCD
- [ ] Create ArgoCD repo secret
- [ ] Run deploy workflow (builds images, syncs ArgoCD)
- [ ] Verify endpoint is accessible

## Common Steps (All Patterns):
- [x] Branch created
- [x] Folder structure created
- [ ] Initial commit pushed
- [ ] ECR repositories created (tagged)
- [ ] Namespace created (labeled)
- [ ] ArgoCD application created: speri-008-argo-dev
- [ ] Deployment verified

---
Created: 2026-01-07
