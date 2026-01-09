# 🚀 Execute Deployment - your-username

## ✅ Status: Ready to Deploy

All files have been committed and pushed to: `prospectf500-app1-opsera` branch

## 📋 Prerequisites Check

Before starting, verify:

- [ ] GitHub Secrets configured:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - **Check**: https://github.com/akhilsathwik/prospectf-opsera/settings/secrets/actions

## 🎯 Step-by-Step Execution

### STEP 1: Create Infrastructure (First Time - ~20 minutes)

**Action Required**: Trigger GitHub Actions workflow

1. **Open**: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/your-username-infra.yaml

2. **Click**: "Run workflow" button (top right, green)

3. **Configure**:
   - **Action**: Select `apply` from dropdown
   - **Branch**: `prospectf500-app1-opsera`

4. **Click**: "Run workflow" (green button at bottom)

5. **Monitor**: 
   - Watch the workflow run
   - Check each step completes successfully
   - Wait for "Terraform Apply" to finish (~15-20 minutes)

**Expected Output**:
- ✅ ArgoCD EKS cluster: `argocd-eu-north-1`
- ✅ Workload EKS cluster: `opsera-se-eu-north-1-nonprod`
- ✅ ECR repositories created
- ✅ S3 bucket: `your-username-tfstate`
- ✅ DynamoDB table: `your-username-tfstate-lock`

**⚠️ Important**: Wait for this step to complete before proceeding!

---

### STEP 2: Install ArgoCD (First Time Only)

After infrastructure is created, install ArgoCD on the ArgoCD cluster.

**Run these commands** (in PowerShell or terminal):

```powershell
# Configure kubectl for ArgoCD cluster
aws eks update-kubeconfig --name argocd-eu-north-1 --region eu-north-1

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready (takes 2-3 minutes)
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get admin password (save this!)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
Write-Host ""  # New line
```

**Expected Output**:
- ✅ ArgoCD namespace created
- ✅ ArgoCD pods running
- ✅ Admin password displayed

**Save the password** - you'll need it to access ArgoCD UI later.

---

### STEP 3: Configure ArgoCD Application

Apply the ArgoCD application manifest to register your app.

**Run these commands**:

```powershell
# Make sure you're on the ArgoCD cluster
aws eks update-kubeconfig --name argocd-eu-north-1 --region eu-north-1

# Apply ArgoCD application
kubectl apply -f your-username-opsera/argocd/application.yaml

# Verify application created
kubectl get applications -n argocd

# Check application status
kubectl describe application your-username-dev -n argocd
```

**Expected Output**:
- ✅ Application `your-username-dev` created in ArgoCD
- ✅ Application shows "Synced" or "Progressing" status

---

### STEP 4: Deploy Application (~15 minutes)

**Action Required**: Trigger GitHub Actions workflow

1. **Open**: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/your-username-deploy.yaml

2. **Click**: "Run workflow" button (top right, green)

3. **Configure**:
   - **Branch**: `prospectf500-app1-opsera`

4. **Click**: "Run workflow" (green button at bottom)

5. **Monitor**:
   - Watch each job:
     - `discover-infrastructure` - Should detect greenfield deployment
     - `build-and-push` - Builds Docker images, pushes to ECR
     - `update-manifests` - Updates kustomization.yaml with image tags
     - `deploy-to-cluster` - Deploys to Kubernetes
     - `verify-endpoint` - Verifies HTTP 200 response
   - Wait for all jobs to complete (~10-15 minutes)

**Expected Output**:
- ✅ Docker images built and pushed to ECR
- ✅ Grype security scan passed
- ✅ Kubernetes manifests updated
- ✅ Pods deployed and running
- ✅ LoadBalancer endpoint provisioned
- ✅ Endpoint verification passed (HTTP 200)

---

### STEP 5: Verify Deployment

After deployment completes, verify everything is working:

**Run these commands**:

```powershell
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

# Get LoadBalancer endpoint
$ENDPOINT = kubectl get svc your-username-frontend -n your-username-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Write-Host "LoadBalancer Endpoint: $ENDPOINT"

# Test endpoint
curl http://$ENDPOINT
```

**Success Criteria**:
- ✅ All pods in "Running" state
- ✅ Frontend service has LoadBalancer endpoint
- ✅ Endpoint responds with HTTP 200
- ✅ No ImagePullBackOff or CrashLoopBackOff errors

---

## 🔗 Quick Links

- **Infrastructure Workflow**: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/your-username-infra.yaml
- **Deployment Workflow**: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/your-username-deploy.yaml
- **GitHub Secrets**: https://github.com/akhilsathwik/prospectf-opsera/settings/secrets/actions
- **Repository**: https://github.com/akhilsathwik/prospectf-opsera

## ⏱️ Expected Timeline

| Step | Duration | Status |
|------|----------|--------|
| 1. Infrastructure Creation | 15-20 min | ⏳ Pending |
| 2. ArgoCD Installation | 2-3 min | ⏳ Pending |
| 3. ArgoCD Application | 1 min | ⏳ Pending |
| 4. Application Deployment | 10-15 min | ⏳ Pending |
| 5. Verification | 2-3 min | ⏳ Pending |
| **Total** | **~30-40 min** | |

## 🐛 Troubleshooting

### Infrastructure Workflow Fails

**Issue**: "AWS credentials not found"
- **Solution**: Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in GitHub Secrets

**Issue**: "Terraform resource already exists"
- **Solution**: The workflow auto-imports existing resources. Check logs for specific errors.

### Deployment Workflow Fails

**Issue**: "ImagePullBackOff" in pods
- **Solution**: 
  ```powershell
  kubectl describe pod <pod-name> -n your-username-dev
  ```
  Verify ECR image URL is correct (no placeholders)

**Issue**: "LoadBalancer pending"
- **Solution**: Wait 3-5 minutes. AWS needs time to provision LoadBalancer.

**Issue**: "Endpoint verification fails"
- **Solution**: 
  1. Check pod logs: `kubectl logs -n your-username-dev deployment/your-username-frontend`
  2. Verify LoadBalancer DNS: `nslookup <endpoint>`
  3. Check security groups allow port 80

## ✅ Deployment Checklist

- [ ] Step 1: Infrastructure created (workflow completed)
- [ ] Step 2: ArgoCD installed (pods running)
- [ ] Step 3: ArgoCD application configured
- [ ] Step 4: Application deployed (workflow completed)
- [ ] Step 5: Deployment verified (pods running, endpoint accessible)

---

## 🎉 Next Steps After Deployment

1. **Set up DNS** (optional): Create Route53 record pointing to LoadBalancer
2. **Update CORS** (if needed): Add production URL to backend CORS origins in `backend/main.py`
3. **Configure monitoring**: Set up CloudWatch metrics
4. **Enable auto-deploy**: Push to branch triggers automatic deployment

---

**Ready?** Start with **STEP 1: Create Infrastructure**!
