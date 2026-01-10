# 🚀 Deploy Now - Quick Start Guide

## Pre-Deployment Checklist

- [ ] GitHub Secrets configured:
  - [ ] `AWS_ACCESS_KEY_ID`
  - [ ] `AWS_SECRET_ACCESS_KEY`
- [ ] ArgoCD application repo URL updated (if different from default)
- [ ] All files committed to repository

## Step 1: Commit and Push Changes

```bash
# Navigate to repository root
cd /path/to/prospectf500-App1-main

# Check current branch
git branch

# If not on main, switch to main
git checkout main

# Add all changes
git add .

# Commit changes
git commit -m "Add your-username deployment configuration for us-west-2"

# Push to GitHub
git push origin main
```

## Step 2: Trigger Deployment Workflow

### Option A: Via GitHub Web UI (Recommended)

1. Go to your GitHub repository
2. Click on **Actions** tab
3. Select **"Deploy to AWS EKS"** workflow from the left sidebar
4. Click **"Run workflow"** button (top right)
5. Verify inputs:
   - Tenant name: `opsera-se`
   - Application name: `your-username`
   - Environment: `dev`
   - AWS region: `us-west-2`
6. Click **"Run workflow"**

### Option B: Via GitHub CLI

```bash
# Install GitHub CLI if not installed
# Windows: winget install GitHub.cli
# Mac: brew install gh
# Linux: See https://cli.github.com/

# Authenticate (if not already)
gh auth login

# Trigger workflow
gh workflow run "Deploy to AWS EKS" \
  --ref main \
  -f tenant_name=opsera-se \
  -f app_name=your-username \
  -f app_env=dev \
  -f app_region=us-west-2
```

### Option C: Via PowerShell Script

```powershell
# Run this from repository root
gh workflow run "Deploy to AWS EKS" `
  --ref main `
  -f tenant_name=opsera-se `
  -f app_name=your-username `
  -f app_env=dev `
  -f app_region=us-west-2

Write-Host "✅ Workflow triggered! Monitor at: https://github.com/YOUR_ORG/YOUR_REPO/actions" -ForegroundColor Green
```

## Step 3: Monitor Deployment

### Watch Workflow Progress

1. Go to **Actions** tab in GitHub
2. Click on the running workflow
3. Monitor each phase:
   - **Phase 1: Infrastructure** (15-20 min)
     - VPC creation
     - EKS cluster creation
     - Node group creation
     - ArgoCD installation
   - **Phase 2: Application** (10-15 min)
     - Docker image build
     - ECR push
     - Manifest updates
   - **Phase 3: Verification** (5-10 min)
     - ArgoCD sync
     - Pod readiness
     - Endpoint verification

### Check Logs

Click on any job to see detailed logs. Common things to watch for:

- ✅ Infrastructure discovery
- ✅ Resource creation
- ✅ Image build and push
- ✅ ArgoCD sync status
- ✅ Endpoint HTTP 200 verification

## Step 4: Get Your Endpoint

After successful deployment, the endpoint URL will be in:

1. **GitHub Actions Summary**: Check the "Summary" step in Phase 3
2. **Kubernetes Service**: Run this command:

```bash
# Configure kubectl
aws eks update-kubeconfig --name opsera-usw2-np --region us-west-2

# Get endpoint
kubectl get svc your-username-frontend -n your-username-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Expected Timeline

| Phase | Duration | What Happens |
|-------|----------|--------------|
| Infrastructure | 15-20 min | VPC, EKS clusters, ECR, ArgoCD |
| Application | 10-15 min | Build, push images, update manifests |
| Verification | 5-10 min | ArgoCD sync, endpoint check |
| **Total** | **30-45 min** | Complete deployment |

## Troubleshooting

### Workflow Fails at Infrastructure Phase

**Issue**: Terraform or AWS CLI errors
- Check AWS credentials in GitHub Secrets
- Verify IAM permissions for EKS, ECR, VPC creation
- Check AWS region availability

### Workflow Fails at Application Phase

**Issue**: Docker build or ECR push fails
- Verify Dockerfile exists in `backend/` and `frontend/`
- Check ECR repository was created
- Verify image tags are correct

### Workflow Fails at Verification Phase

**Issue**: ArgoCD sync or endpoint verification fails
- Check ArgoCD application manifest path
- Verify repository URL in `application.yaml`
- Check pod logs: `kubectl logs -n your-username-dev deployment/your-username-backend`

### Pods Stuck in ImagePullBackOff

**Issue**: Cannot pull images from ECR
- Verify images exist: `aws ecr describe-images --repository-name opsera-se/your-username-backend`
- Check ECR repository permissions
- Verify image tags in `kustomization.yaml` (should NOT have placeholders)

## Post-Deployment

### Access Your Application

```bash
# Get endpoint
ENDPOINT=$(kubectl get svc your-username-frontend -n your-username-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test endpoint
curl http://$ENDPOINT

# Or open in browser
echo "Open: http://$ENDPOINT"
```

### Check Application Status

```bash
# Check pods
kubectl get pods -n your-username-dev

# Check services
kubectl get svc -n your-username-dev

# Check ArgoCD application
kubectl get application your-username-dev -n argocd
```

### View Logs

```bash
# Backend logs
kubectl logs -n your-username-dev deployment/your-username-backend -f

# Frontend logs
kubectl logs -n your-username-dev deployment/your-username-frontend -f
```

## Next Steps

1. ✅ **Deployment Complete** - Your app is live!
2. 🔄 **Configure HTTPS** - Add ACM certificate for HTTPS
3. 🔄 **Set up DNS** - Point custom domain to LoadBalancer
4. 🔄 **Configure Monitoring** - Set up CloudWatch metrics
5. 🔄 **Add Secrets** - Configure OpenAI API key if needed

---

**Ready to deploy?** Follow Step 1 and Step 2 above! 🚀
