# Next Steps: your-username Deployment

## ✅ What Has Been Created

1. **Terraform Infrastructure** (`your-username-opsera/terraform/`)
   - EKS clusters (ArgoCD + Workload)
   - ECR repositories
   - IAM roles and policies
   - CloudWatch log groups

2. **Kubernetes Manifests** (`your-username-opsera/k8s/`)
   - Base manifests (namespace, deployments, services)
   - Dev overlay with Kustomize

3. **ArgoCD Application** (`your-username-opsera/argocd/`)
   - Application manifest for GitOps deployment

4. **GitHub Actions Workflows**
   - `your-username-infra.yaml` - Infrastructure provisioning
   - `your-username-deploy.yaml` - Application deployment

## ⚠️ Action Required Before Deployment

### 1. Update ArgoCD Application Repository URL

Edit `your-username-opsera/argocd/application.yaml`:

```yaml
spec:
  source:
    repoURL: https://github.com/YOUR_GITHUB_ORG/YOUR_REPO  # ← UPDATE THIS
```

Replace `YOUR_GITHUB_ORG/YOUR_REPO` with your actual GitHub repository.

### 2. Update Frontend Nginx Configuration (Optional)

The frontend `nginx.conf` currently has hardcoded service name `prospectf500-app1-backend`. 

For your-username deployment, you may want to:
- Option A: Use environment variable (recommended)
- Option B: Create deployment-specific nginx.conf
- Option C: Keep as-is if backend service name matches

Current service name in nginx.conf: `prospectf500-app1-backend`  
Required service name: `your-username-backend`

**Quick Fix**: Update `frontend/nginx.conf` to use `your-username-backend` instead of `prospectf500-app1-backend` in all proxy_pass directives.

### 3. Configure GitHub Secrets

Ensure these secrets are configured in your GitHub repository:

- `AWS_ACCESS_KEY_ID` - AWS credentials
- `AWS_SECRET_ACCESS_KEY` - AWS credentials

## 🚀 Deployment Sequence

### Step 1: Create Infrastructure (First Time Only)

1. Go to: **GitHub Actions** → **"your-username Infrastructure"**
2. Click: **"Run workflow"**
3. Select:
   - Action: **apply**
   - Branch: **main**
4. Click: **"Run workflow"**
5. Wait: ~15-20 minutes for infrastructure creation

**What it creates:**
- ArgoCD EKS cluster: `argocd-eu-north-1`
- Workload EKS cluster: `opsera-se-eu-north-1-nonprod`
- ECR repositories: `opsera-se/your-username-backend`, `opsera-se/your-username-frontend`
- S3 bucket: `your-username-tfstate`
- DynamoDB table: `your-username-tfstate-lock`

### Step 2: Install ArgoCD (First Time Only)

After infrastructure is created:

```bash
# Configure kubectl for ArgoCD cluster
aws eks update-kubeconfig --name argocd-eu-north-1 --region eu-north-1

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Step 3: Configure ArgoCD Application

1. Update `your-username-opsera/argocd/application.yaml` with your GitHub repo URL
2. Apply the application:

```bash
kubectl apply -f your-username-opsera/argocd/application.yaml
```

### Step 4: Deploy Application

1. Go to: **GitHub Actions** → **"your-username Deploy"**
2. Click: **"Run workflow"**
3. Select:
   - Branch: **main**
4. Click: **"Run workflow"**
5. Wait: ~10-15 minutes for deployment

**What it does:**
- Builds Docker images (backend + frontend)
- Pushes to ECR
- Runs Grype security scan
- Updates Kubernetes manifests
- Deploys to workload cluster
- Verifies endpoint accessibility

## 🔍 Verification

After deployment completes:

```bash
# Configure kubectl for workload cluster
aws eks update-kubeconfig --name opsera-se-eu-north-1-nonprod --region eu-north-1

# Check pods
kubectl get pods -n your-username-dev

# Check services
kubectl get svc -n your-username-dev

# Get LoadBalancer endpoint
kubectl get svc your-username-frontend -n your-username-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test endpoint
ENDPOINT=$(kubectl get svc your-username-frontend -n your-username-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$ENDPOINT
```

## 📋 Resource Summary

| Resource | Name |
|----------|------|
| ArgoCD Cluster | `argocd-eu-north-1` |
| Workload Cluster | `opsera-se-eu-north-1-nonprod` |
| Namespace | `your-username-dev` |
| Backend Service | `your-username-backend` |
| Frontend Service | `your-username-frontend` |
| ECR Backend | `opsera-se/your-username-backend` |
| ECR Frontend | `opsera-se/your-username-frontend` |

## 🐛 Troubleshooting

### Infrastructure Creation Fails

- Check AWS credentials in GitHub Secrets
- Verify AWS region `eu-north-1` is accessible
- Check Terraform logs in GitHub Actions

### ImagePullBackOff

- Verify ECR repository URLs in `kustomization.yaml` (no placeholders)
- Check ECR image exists: `aws ecr describe-images --repository-name opsera-se/your-username-backend`

### LoadBalancer Pending

- Wait 3-5 minutes for AWS to provision LoadBalancer
- Check subnet tags (for AWS LoadBalancer Controller)

### Deployment Fails

- Check GitHub Actions logs
- Verify all required secrets are configured
- Check Kubernetes events: `kubectl get events -n your-username-dev --sort-by='.lastTimestamp'`

## 📚 Additional Resources

- [Deployment Context](./DEPLOYMENT-CONTEXT.md) - Detailed deployment information
- [Terraform Documentation](https://www.terraform.io/docs)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## ✅ Checklist

- [ ] Updated ArgoCD application.yaml with GitHub repo URL
- [ ] Updated frontend nginx.conf with correct service name (if needed)
- [ ] Configured GitHub Secrets (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
- [ ] Created infrastructure (Step 1)
- [ ] Installed ArgoCD (Step 2)
- [ ] Applied ArgoCD application (Step 3)
- [ ] Deployed application (Step 4)
- [ ] Verified deployment (pods running, endpoint accessible)

---

**Ready to deploy?** Start with Step 1: Create Infrastructure
