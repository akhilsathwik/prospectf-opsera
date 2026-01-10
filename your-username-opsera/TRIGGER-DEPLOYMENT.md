# Trigger Greenfield Deployment

## Quick Start

### Option 1: GitHub Web UI (Recommended)

1. **Navigate to GitHub Actions**
   - Go to your repository: `https://github.com/YOUR_ORG/YOUR_REPO`
   - Click on **"Actions"** tab
   - Select **"Deploy to AWS EKS"** workflow from the left sidebar

2. **Run the Workflow**
   - Click **"Run workflow"** button (top right)
   - Fill in the inputs:
     ```
     Tenant name: opsera-se
     App name: your-username
     Environment: dev
     Region: us-west-2
     ```
   - Click **"Run workflow"**

3. **Monitor Progress**
   - Watch the workflow run in real-time
   - Check each phase:
     - ✅ Phase 1: Infrastructure (30-45 min)
     - ✅ Phase 2: Application (5-10 min)
     - ✅ Phase 3: Verification (5-10 min)

### Option 2: GitHub CLI

```bash
# Install GitHub CLI if not already installed
# Windows: winget install GitHub.cli
# Mac: brew install gh
# Linux: See https://cli.github.com/

# Authenticate
gh auth login

# Trigger workflow
gh workflow run "Deploy to AWS EKS" \
  --ref main \
  -f tenant_name=opsera-se \
  -f app_name=your-username \
  -f app_env=dev \
  -f app_region=us-west-2

# Monitor workflow
gh run watch
```

### Option 3: PowerShell Script

```powershell
# Save as trigger-deployment.ps1
$repo = "YOUR_ORG/YOUR_REPO"  # Update this
$workflow = "Deploy to AWS EKS"

gh workflow run $workflow `
  --repo $repo `
  --ref main `
  -f tenant_name=opsera-se `
  -f app_name=your-username `
  -f app_env=dev `
  -f app_region=us-west-2

Write-Host "✅ Workflow triggered! Monitor at:"
Write-Host "https://github.com/$repo/actions"
```

## Pre-Deployment Checklist

Before triggering, ensure:

- [ ] **GitHub Secrets Configured**
  - `AWS_ACCESS_KEY_ID` exists
  - `AWS_SECRET_ACCESS_KEY` exists
  - Both have proper AWS permissions (EC2, EKS, ECR, Route53, IAM)

- [ ] **Repository Access**
  - Workflow has `contents: write` permission
  - Can create branches and push commits

- [ ] **Code Committed**
  - All changes committed to `main` branch
  - Workflow file is at `.github/workflows/your-username-deploy.yaml`

## What Happens During Deployment

### Phase 1: Infrastructure (30-45 minutes)

1. **Discovery** (2 min)
   - Checks existing VPC, clusters, ECR repos
   - Determines deployment type (greenfield/brownfield)

2. **Terraform State** (2 min)
   - Creates S3 bucket for state: `opsera-tf-state-{account}-{region}`
   - Creates DynamoDB table for locking

3. **VPC Creation** (5 min)
   - Creates `opsera-vpc` with public/private subnets
   - Sets up NAT gateways and route tables

4. **ECR Repositories** (1 min)
   - Creates `opsera-se/your-username-backend`
   - Creates `opsera-se/your-username-frontend`

5. **ArgoCD Cluster** (15-20 min)
   - Creates `argocd-usw2` EKS cluster
   - Creates node group with 2 nodes
   - Installs ArgoCD

6. **Workload Cluster** (15-20 min)
   - Creates `opsera-se-usw2-np` EKS cluster
   - Creates node group with 2 nodes
   - Creates OIDC provider for IRSA

7. **ExternalDNS** (2 min)
   - Creates IAM role and policy
   - Installs ExternalDNS via Helm

### Phase 2: Application (5-10 minutes)

1. **Branch Setup** (1 min)
   - Creates/checks out `your-username-deploy` branch

2. **Docker Build** (3-5 min)
   - Builds backend image
   - Builds frontend image

3. **Image Push** (2-3 min)
   - Pushes images with SHA tag
   - Pushes images with `latest` tag (Learning #134)

4. **Kustomization Update** (1 min)
   - Updates `k8s/overlays/dev/kustomization.yaml`
   - Commits and pushes changes

### Phase 3: Verification (5-10 minutes)

1. **AWS Credentials Secret** (1 min)
   - Creates `aws-credentials` secret in namespace

2. **ArgoCD Application** (1 min)
   - Applies ArgoCD Application manifest

3. **ArgoCD Sync** (2-3 min)
   - Waits for ArgoCD to sync resources
   - Deploys pods to workload cluster

4. **Pod Verification** (2-3 min)
   - Waits for backend pods ready
   - Waits for frontend pods ready

5. **LoadBalancer** (3-5 min)
   - Waits for LoadBalancer endpoint
   - Verifies HTTP 200 response

## Expected Outputs

After successful deployment:

### Infrastructure
- ✅ VPC: `opsera-vpc`
- ✅ ArgoCD Cluster: `argocd-usw2`
- ✅ Workload Cluster: `opsera-se-usw2-np`
- ✅ ECR Repos: `opsera-se/your-username-backend`, `opsera-se/your-username-frontend`
- ✅ ExternalDNS: Installed and running

### Application
- ✅ Namespace: `your-username-dev`
- ✅ Backend Deployment: 2 replicas
- ✅ Frontend Deployment: 2 replicas
- ✅ LoadBalancer: Internet-facing NLB

### Endpoints
- ✅ HTTP: `http://your-username-dev.agents.opsera-labs.com`
- ✅ LoadBalancer: `http://{nlb-hostname}` (from GitHub Actions summary)

## Troubleshooting

### Workflow Fails at Infrastructure Phase

**Issue**: VPC creation fails
- **Solution**: Check AWS credentials have EC2 permissions
- **Check**: `aws ec2 describe-vpcs` works

**Issue**: EKS cluster creation timeout
- **Solution**: EKS takes 15-20 minutes, increase timeout if needed
- **Check**: `aws eks describe-cluster --name argocd-usw2`

**Issue**: Node group creation fails
- **Solution**: Verify subnet IDs are correct
- **Check**: Subnets have proper tags for EKS

### Workflow Fails at Application Phase

**Issue**: Docker build fails
- **Solution**: Check Dockerfile exists in `backend/` and `frontend/`
- **Check**: Dockerfile syntax is correct

**Issue**: Image push fails
- **Solution**: Verify ECR repository exists
- **Check**: AWS credentials have ECR permissions

**Issue**: Kustomization update fails
- **Solution**: Verify branch exists and has write access
- **Check**: `git push` permissions

### Workflow Fails at Verification Phase

**Issue**: Pods stuck in Pending
- **Solution**: Check node group has capacity
- **Check**: `kubectl get nodes` shows nodes ready

**Issue**: LoadBalancer stuck in Pending
- **Solution**: Verify node role has ELB permissions
- **Check**: IAM role has `elasticloadbalancing:*` policy

**Issue**: ExternalDNS not creating DNS
- **Solution**: Check ExternalDNS logs
- **Check**: `kubectl logs -n kube-system deployment/external-dns`

## Post-Deployment

### Verify Deployment

```bash
# Get cluster kubeconfig
aws eks update-kubeconfig --name opsera-se-usw2-np --region us-west-2

# Check pods
kubectl get pods -n your-username-dev

# Check services
kubectl get svc -n your-username-dev

# Check ArgoCD sync status
aws eks update-kubeconfig --name argocd-usw2 --region us-west-2
kubectl get application your-username-dev -n argocd
```

### Access Application

1. **Via DNS** (after ExternalDNS creates record):
   ```
   http://your-username-dev.agents.opsera-labs.com
   ```

2. **Via LoadBalancer** (immediate):
   ```
   # Get from GitHub Actions summary or:
   kubectl get svc your-username-frontend -n your-username-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```

### Next Steps

1. **Configure HTTPS** (Optional):
   - Request ACM certificate for `your-username-dev.agents.opsera-labs.com`
   - Update service annotation with certificate ARN

2. **Monitor**:
   - Check ArgoCD UI for sync status
   - Monitor pod logs for errors
   - Check ExternalDNS logs for DNS issues

3. **Scale** (if needed):
   - Update replica count in deployment files
   - ArgoCD will auto-sync changes

---

**Ready to deploy?** Follow Option 1 above to trigger via GitHub UI!
