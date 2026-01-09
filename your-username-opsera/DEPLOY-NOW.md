# 🚀 Deploy your-username NOW

## ✅ Pre-Deployment Fixes Applied

1. ✅ **Frontend nginx.conf** - Updated to use `your-username-backend` service name
2. ✅ **ArgoCD Application** - Updated with GitHub repo: `https://github.com/akhilsathwik/prospectf-opsera.git`
3. ✅ **All manifests** - Created and ready

## 📋 Pre-Flight Checklist

Before deploying, ensure:

- [x] GitHub repository URL configured in ArgoCD application
- [x] Frontend nginx.conf updated with correct service name
- [ ] **GitHub Secrets configured** (REQUIRED):
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`

## 🎯 Deployment Steps

### Step 1: Verify GitHub Secrets

Go to your GitHub repository:
1. **Settings** → **Secrets and variables** → **Actions**
2. Verify these secrets exist:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

If missing, add them now.

### Step 2: Create Infrastructure (First Time - ~20 minutes)

1. Go to: **GitHub** → **Actions** tab
2. Select: **"your-username Infrastructure"** workflow
3. Click: **"Run workflow"** button (top right)
4. Configure:
   - **Action**: `apply`
   - **Branch**: `main` (or your branch)
5. Click: **"Run workflow"** (green button)
6. **Wait**: ~15-20 minutes for infrastructure creation

**What this creates:**
- ✅ ArgoCD EKS cluster: `argocd-eu-north-1`
- ✅ Workload EKS cluster: `opsera-se-eu-north-1-nonprod`
- ✅ ECR repositories: `opsera-se/your-username-backend`, `opsera-se/your-username-frontend`
- ✅ S3 bucket: `your-username-tfstate`
- ✅ DynamoDB table: `your-username-tfstate-lock`

**Monitor progress:**
- Watch the workflow run in GitHub Actions
- Check for any errors in the logs
- Wait for "Terraform Apply" step to complete

### Step 3: Install ArgoCD (First Time Only)

After infrastructure is created, install ArgoCD on the ArgoCD cluster:

```bash
# Configure kubectl for ArgoCD cluster
aws eks update-kubeconfig --name argocd-eu-north-1 --region eu-north-1

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready (takes 2-3 minutes)
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""  # New line after password
```

**Save the password** - you'll need it to access ArgoCD UI.

### Step 4: Configure ArgoCD Application

Apply the ArgoCD application manifest:

```bash
# Make sure you're on the ArgoCD cluster
aws eks update-kubeconfig --name argocd-eu-north-1 --region eu-north-1

# Apply ArgoCD application
kubectl apply -f your-username-opsera/argocd/application.yaml

# Verify application created
kubectl get applications -n argocd
```

### Step 5: Deploy Application (~15 minutes)

1. Go to: **GitHub** → **Actions** tab
2. Select: **"your-username Deploy"** workflow
3. Click: **"Run workflow"** button
4. Configure:
   - **Branch**: `main` (or your branch)
5. Click: **"Run workflow"** (green button)
6. **Wait**: ~10-15 minutes for deployment

**What this does:**
- ✅ Builds Docker images (backend + frontend)
- ✅ Pushes images to ECR
- ✅ Runs Grype security scan
- ✅ Updates Kubernetes manifests with image tags
- ✅ Deploys to workload cluster
- ✅ Verifies endpoint is accessible

**Monitor progress:**
- Watch the workflow run
- Check each job:
  - `discover-infrastructure` - Should show greenfield deployment
  - `build-and-push` - Builds and pushes images
  - `update-manifests` - Updates kustomization.yaml
  - `deploy-to-cluster` - Deploys to Kubernetes
  - `verify-endpoint` - Verifies HTTP 200 response

## 🔍 Verification

After deployment completes, verify everything is working:

```bash
# Configure kubectl for workload cluster
aws eks update-kubeconfig --name opsera-se-eu-north-1-nonprod --region eu-north-1

# Check pods are running
kubectl get pods -n your-username-dev

# Expected output:
# NAME                                    READY   STATUS    RESTARTS   AGE
# your-username-backend-xxxxx-xxxxx      1/1     Running   0          2m
# your-username-frontend-xxxxx-xxxxx     1/1     Running   0          2m

# Check services
kubectl get svc -n your-username-dev

# Expected output:
# NAME                      TYPE           CLUSTER-IP      EXTERNAL-IP
# your-username-backend     ClusterIP      10.100.x.x      <none>
# your-username-frontend    LoadBalancer   10.100.x.x      xxxxxx.eu-north-1.elb.amazonaws.com

# Get LoadBalancer endpoint
kubectl get svc your-username-frontend -n your-username-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""

# Test endpoint
ENDPOINT=$(kubectl get svc your-username-frontend -n your-username-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -v http://$ENDPOINT
```

## 🐛 Troubleshooting

### Infrastructure Workflow Fails

**Issue**: Terraform fails with "resource already exists"
- **Solution**: The workflow will auto-import existing resources. If it still fails, check the logs.

**Issue**: AWS credentials error
- **Solution**: Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set in GitHub Secrets

### Deployment Workflow Fails

**Issue**: ImagePullBackOff in pods
- **Solution**: 
  ```bash
  kubectl describe pod <pod-name> -n your-username-dev
  ```
  Check if ECR image URL is correct (no placeholders)

**Issue**: LoadBalancer stuck in "Pending"
- **Solution**: Wait 3-5 minutes. AWS needs time to provision the LoadBalancer.

**Issue**: Endpoint verification fails
- **Solution**: 
  1. Check pod logs: `kubectl logs -n your-username-dev deployment/your-username-frontend`
  2. Verify LoadBalancer DNS resolves: `nslookup <endpoint>`
  3. Check security groups allow traffic on port 80

### ArgoCD Sync Issues

**Issue**: ArgoCD application shows "Unknown" or "Error"
- **Solution**: 
  ```bash
  kubectl describe application your-username-dev -n argocd
  ```
  Check the events for specific errors.

## 📊 Expected Timeline

| Step | Duration | Status |
|------|----------|--------|
| Infrastructure Creation | 15-20 min | ⏳ Pending |
| ArgoCD Installation | 2-3 min | ⏳ Pending |
| Application Deployment | 10-15 min | ⏳ Pending |
| **Total** | **~30-40 min** | |

## ✅ Success Criteria

Deployment is successful when:

1. ✅ All GitHub Actions workflows complete without errors
2. ✅ Pods are in "Running" state (not ImagePullBackOff/CrashLoopBackOff)
3. ✅ Frontend service has LoadBalancer endpoint
4. ✅ Endpoint responds with HTTP 200
5. ✅ ArgoCD application shows "Synced" status

## 🎉 Next Steps After Deployment

1. **Set up DNS** (optional): Create Route53 record pointing to LoadBalancer
2. **Update CORS** (if needed): Add production URL to backend CORS origins
3. **Configure monitoring**: Set up CloudWatch metrics
4. **Set up CI/CD**: Enable automatic deployments on push

---

**Ready?** Start with **Step 1: Verify GitHub Secrets**, then proceed to **Step 2: Create Infrastructure**
