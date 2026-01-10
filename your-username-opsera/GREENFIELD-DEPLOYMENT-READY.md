# Greenfield Deployment Ready - your-username

## Deployment Configuration

| Input | Value |
|-------|-------|
| **Tenant Name** | opsera-se |
| **Application Name** | your-username |
| **Environment** | dev |
| **AWS Region** | us-west-2 |
| **Deployment Type** | Greenfield |

## Resource Names (Short Convention)

| Resource | Name | Source |
|----------|------|--------|
| **VPC** | opsera-vpc | Default (shared) |
| **ArgoCD Cluster** | argocd-usw2 | Short region code |
| **Workload Cluster** | opsera-se-usw2-np | Tenant + region + env |
| **ECR Repository** | opsera-se/your-username | Tenant/App |
| **Namespace** | your-username-dev | App-Env |
| **Deploy Branch** | your-username-deploy | App-deploy |

## What Will Be Created (Greenfield)

### Phase 1: Infrastructure
- ✅ **VPC** with public/private subnets, NAT gateways
- ✅ **ArgoCD EKS Cluster** (`argocd-usw2`) with node group
- ✅ **Workload EKS Cluster** (`opsera-se-usw2-np`) with node group
- ✅ **ECR Repositories** for backend and frontend
- ✅ **ExternalDNS** installed with IRSA for automatic DNS management
- ✅ **ArgoCD** installed on ArgoCD cluster
- ✅ **OIDC Provider** created for IRSA support

### Phase 2: Application
- ✅ **Docker Images** built and pushed to ECR (with SHA and `latest` tags)
- ✅ **Kustomization** updated with image references
- ✅ **ArgoCD Application** created to sync workloads

### Phase 3: Verification
- ✅ **AWS Credentials Secret** created for IRSA fallback
- ✅ **Pods** verified as ready
- ✅ **LoadBalancer Endpoint** verified with HTTP 200

## Key Features Included

### v1.10.0 Features
- ✅ **Learning #134**: Images tagged with BOTH SHA and `latest`
- ✅ **Learning #135**: HTTPS annotations ready (certificate can be added later)
- ✅ **Learning #128**: ExternalDNS automatically installed for greenfield
- ✅ **Learning #124**: OIDC provider created for IRSA
- ✅ **Learning #139-143**: AWS credentials secret pattern for IRSA fallback

### Infrastructure Best Practices
- ✅ **Short Naming Convention**: `argocd-usw2`, `opsera-se-usw2-np`
- ✅ **Region-Specific State**: Terraform state bucket per region
- ✅ **Separate Clusters**: ArgoCD and workload clusters isolated
- ✅ **IRSA Support**: OIDC provider + service account annotations

## Deployment Steps

### 1. Pre-Flight Checks
```bash
# Verify GitHub Secrets exist:
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY
```

### 2. Trigger Deployment
1. Go to GitHub Actions → "Deploy to AWS EKS"
2. Click "Run workflow"
3. Fill in inputs:
   - Tenant name: `opsera-se`
   - App name: `your-username`
   - Environment: `dev`
   - Region: `us-west-2`
4. Click "Run workflow"

### 3. Monitor Progress
- **Phase 1** (Infrastructure): ~30-45 minutes
  - VPC creation: ~5 minutes
  - EKS clusters: ~15-20 minutes each
  - Node groups: ~5-10 minutes each
  - ExternalDNS: ~2 minutes
  - ArgoCD: ~5 minutes

- **Phase 2** (Application): ~5-10 minutes
  - Docker build: ~3-5 minutes
  - Image push: ~2-3 minutes
  - Kustomization update: ~1 minute

- **Phase 3** (Verification): ~5-10 minutes
  - ArgoCD sync: ~2-3 minutes
  - Pod startup: ~2-3 minutes
  - LoadBalancer: ~3-5 minutes

### 4. Access Your Application

After deployment completes, your application will be available at:

**HTTP**: `http://your-username-dev.agents.opsera-labs.com`  
**HTTPS**: `https://your-username-dev.agents.opsera-labs.com` (after certificate is configured)

The LoadBalancer endpoint will also be available directly (check GitHub Actions summary).

## Files Structure

```
your-username-opsera/
├── argocd/
│   └── application.yaml          # ArgoCD Application manifest
├── k8s/
│   ├── base/
│   │   ├── namespace.yaml
│   │   ├── backend-deployment.yaml
│   │   ├── backend-service.yaml
│   │   ├── frontend-deployment.yaml
│   │   ├── frontend-service.yaml  # With ExternalDNS + HTTPS annotations
│   │   └── kustomization.yaml
│   └── overlays/
│       └── dev/
│           └── kustomization.yaml # Image tags updated here
└── terraform/
    ├── main.tf                    # Infrastructure as Code
    └── variables.tf
```

## Next Steps After Deployment

1. **Verify DNS**: Check that `your-username-dev.agents.opsera-labs.com` resolves
2. **Test Application**: Access the frontend and test backend connectivity
3. **Configure HTTPS** (Optional): Add ACM certificate ARN to service annotations
4. **Monitor**: Check ArgoCD UI for sync status
5. **Scale** (if needed): Update replica counts in deployment files

## Troubleshooting

### Pods Stuck in Pending
- Check node group status: `aws eks describe-nodegroup --cluster-name opsera-se-usw2-np --nodegroup-name workload-nodes`
- Verify node group has capacity

### DNS Not Working
- Check ExternalDNS logs: `kubectl logs -n kube-system deployment/external-dns`
- Verify IAM role has Route53 permissions

### ImagePullBackOff
- Verify images exist in ECR: `aws ecr list-images --repository-name opsera-se/your-username-backend`
- Check both SHA and `latest` tags exist

### LoadBalancer Stuck in Pending
- Verify node role has ELB permissions
- Check security groups allow traffic

## Support

For issues or questions:
1. Check GitHub Actions workflow logs
2. Review ArgoCD application status
3. Check Kubernetes events: `kubectl get events -n your-username-dev`

---

**Status**: ✅ Ready for Greenfield Deployment  
**Last Updated**: 2026-01-10  
**Workflow Version**: v1.10.0
