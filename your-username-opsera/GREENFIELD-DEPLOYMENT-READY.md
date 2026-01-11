# Greenfield Deployment Ready for ap-south-1

## ✅ Configuration Summary

| Input | Value |
|-------|-------|
| **Tenant Name** | opsera-se |
| **Application Name** | your-username |
| **Environment** | dev |
| **AWS Region** | ap-south-1 |
| **Deployment Type** | Greenfield |

## 📋 Resource Names (Short Convention)

| Resource | Name | Notes |
|----------|------|-------|
| **VPC** | opsera-vpc | Shared VPC for all deployments |
| **ArgoCD Cluster** | argocd-aps1 | Control plane cluster |
| **Workload Cluster** | opsera-se-aps1-np | Application workload cluster |
| **ECR Repository** | opsera-se/your-username | Backend: `-backend`, Frontend: `-frontend` |
| **Namespace** | your-username-dev | Kubernetes namespace |
| **Deploy Branch** | your-username-deploy | Git branch for K8s manifests |

## 🚀 What Was Configured

### 1. GitHub Actions Workflow
- ✅ Updated `.github/workflows/your-username-deploy.yaml`
- ✅ Added support for `ap-south-1` region (short code: `aps1`)
- ✅ Implemented all critical learnings:
  - **Learning #158**: Multi-cluster ArgoCD with ServiceAccount token
  - **Learning #159**: Bootstrap creates infrastructure (S3 backend, VPC, EKS, ECR)
  - **Learning #160**: Deploy branch strategy (workflows in main, artifacts in deploy branch)
  - **Learning #161**: ArgoCD cluster connectivity via workload cluster endpoint
  - **Learning #162**: ArgoCD Repository Secret for private repo access
  - **Learning #163**: LoadBalancer subnet tags (public: `elb=1`, private: `internal-elb=1`)
  - **Learning #164**: ArgoCD Application applied to cluster (not just in Git)

### 2. Infrastructure Components
- ✅ **VPC**: Public and private subnets with proper tags for LoadBalancer
- ✅ **EKS Clusters**: ArgoCD cluster and workload cluster
- ✅ **ECR Repositories**: Backend and frontend image repositories
- ✅ **OIDC Provider**: For IRSA (IAM Roles for Service Accounts)
- ✅ **ExternalDNS**: Automatic DNS record management
- ✅ **ArgoCD**: GitOps deployment controller

### 3. Kubernetes Manifests
- ✅ Base manifests in `your-username-opsera/k8s/base/`
- ✅ Dev overlay in `your-username-opsera/k8s/overlays/dev/`
- ✅ ArgoCD Application in `your-username-opsera/argocd/application.yaml`

## 📝 Pre-Deployment Checklist

Before triggering the deployment, ensure:

- [ ] GitHub Secrets are configured:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `GITHUB_TOKEN` (automatically available)

- [ ] Workflow file is committed to `main` branch (Learning #147)

- [ ] Repository is accessible (public or private with proper permissions)

## 🎯 How to Trigger Deployment

### Option 1: GitHub Actions UI
1. Go to your repository on GitHub
2. Navigate to **Actions** tab
3. Select **"Deploy to AWS EKS"** workflow
4. Click **"Run workflow"**
5. Fill in the inputs:
   - **Tenant name**: `opsera-se`
   - **App name**: `your-username`
   - **App env**: `dev`
   - **App region**: `ap-south-1`
6. Click **"Run workflow"**

### Option 2: GitHub CLI
```bash
gh workflow run "Deploy to AWS EKS" \
  --ref main \
  -f tenant_name=opsera-se \
  -f app_name=your-username \
  -f app_env=dev \
  -f app_region=ap-south-1
```

## ⏱️ Expected Deployment Time

| Phase | Duration | Description |
|-------|----------|-------------|
| **Infrastructure** | 30-45 min | VPC, EKS clusters, ECR, ExternalDNS, ArgoCD |
| **Application** | 5-10 min | Build, push images, update manifests |
| **Verification** | 5-10 min | Wait for pods, verify endpoint |
| **Total** | **40-65 minutes** | Complete greenfield deployment |

## 📊 Deployment Phases

### Phase 1: Infrastructure
- ✅ Discover existing resources
- ✅ Create S3 backend bucket (region-specific)
- ✅ Create VPC with public/private subnets
- ✅ Create ArgoCD EKS cluster + node group
- ✅ Create Workload EKS cluster + node group
- ✅ Create OIDC provider for IRSA
- ✅ Install ExternalDNS
- ✅ Install ArgoCD
- ✅ Register workload cluster with ArgoCD
- ✅ Create ArgoCD Repository Secret

### Phase 2: Application
- ✅ Checkout/create deploy branch
- ✅ Build backend and frontend Docker images
- ✅ Push images to ECR (with SHA and `latest` tags)
- ✅ Update kustomization.yaml with image tags
- ✅ Commit changes to deploy branch

### Phase 3: Verification
- ✅ Create AWS credentials secret (IRSA fallback)
- ✅ Apply ArgoCD Application to cluster
- ✅ Wait for ArgoCD sync
- ✅ Verify pods are running
- ✅ Verify LoadBalancer endpoint
- ✅ Test HTTP 200 response

## 🔍 Monitoring Deployment

### View Workflow Progress
```bash
# Watch workflow run
gh run watch

# View logs
gh run view --log
```

### Check Infrastructure Status
```bash
# Check EKS clusters
aws eks describe-cluster --name argocd-aps1 --region ap-south-1
aws eks describe-cluster --name opsera-se-aps1-np --region ap-south-1

# Check ECR repositories
aws ecr describe-repositories --region ap-south-1 | grep your-username

# Check VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=opsera-vpc" --region ap-south-1
```

### Check Kubernetes Resources
```bash
# Configure kubectl for workload cluster
aws eks update-kubeconfig --name opsera-se-aps1-np --region ap-south-1

# Check namespace
kubectl get namespace your-username-dev

# Check pods
kubectl get pods -n your-username-dev

# Check services
kubectl get svc -n your-username-dev

# Check ArgoCD Application (from ArgoCD cluster)
aws eks update-kubeconfig --name argocd-aps1 --region ap-south-1
kubectl get application your-username-dev -n argocd
```

## 🌐 Expected Endpoint

After successful deployment, your application will be accessible at:

- **LoadBalancer URL**: `http://<nlb-dns-name>` (from `kubectl get svc`)
- **DNS Hostname**: `your-username-dev.agents.opsera-labs.com` (if ExternalDNS is configured)

## ⚠️ Important Notes

1. **EKS Version**: Using Kubernetes 1.28. Verify availability in `ap-south-1` if deployment fails.

2. **Cluster Creation Time**: EKS clusters take 10-15 minutes to become ACTIVE. Be patient!

3. **ArgoCD Sync**: After infrastructure is created, ArgoCD will automatically sync your application from the `your-username-deploy` branch.

4. **IRSA Fallback**: The workflow creates an `aws-credentials` secret as a fallback if OIDC provider setup fails.

5. **Deploy Branch**: All K8s manifests must be in the `your-username-deploy` branch. The workflow will create this branch if it doesn't exist.

## 🐛 Troubleshooting

### Workflow Not Found
- **Issue**: Workflow not visible in GitHub Actions
- **Fix**: Ensure workflow file is committed to `main` branch (Learning #147)

### Cluster Creation Timeout
- **Issue**: EKS cluster stuck in CREATING state
- **Fix**: Wait 15-20 minutes. EKS clusters take time to provision.

### ArgoCD Sync Fails
- **Issue**: Application not syncing
- **Fix**: 
  - Check if workload cluster is registered: `kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster`
  - Check Repository Secret: `kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository`

### LoadBalancer Stuck in Pending
- **Issue**: Service LoadBalancer not provisioning
- **Fix**: Verify subnet tags:
  - Public subnets: `kubernetes.io/role/elb=1`
  - Private subnets: `kubernetes.io/role/internal-elb=1`

### DNS Not Working
- **Issue**: ExternalDNS not creating DNS records
- **Fix**: 
  - Check ExternalDNS pod logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns`
  - Verify IAM role has Route53 permissions
  - Check hosted zone exists in Route53

## 📚 References

- [Unified AWS Container EKS Documentation](../MCP-AGENTIC-TESTING.md)
- [145 Verified Fixes](../MCP-AGENTIC-TESTING.md#verified-fixes-145-total)
- [Critical Learnings](../MCP-AGENTIC-TESTING.md#v1170-release-notes-multi-cluster-argocd-support)

---

**Ready to deploy?** Trigger the workflow using one of the methods above! 🚀
