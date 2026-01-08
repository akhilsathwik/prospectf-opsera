# Next Steps - Application Deployment

**Status:** ✅ Infrastructure is ready!  
**Date:** 2026-01-08

---

## ✅ Completed Steps

1. ✅ **Infrastructure Created**
   - VPC, EKS clusters (ArgoCD + Workload)
   - ECR repositories (backend + frontend)
   - IAM roles and S3 backend

2. ✅ **ArgoCD Installed**
   - ArgoCD running on management cluster (`prospectf500-app1-cd`)
   - All ArgoCD pods in Running state

3. ✅ **ExternalDNS Installed**
   - ExternalDNS running on workload cluster (`prospectf500-app1-wrk-dev`)
   - IRSA configured for Route53 access

4. ✅ **ArgoCD Application Setup** (NEW)
   - Workload cluster registered with ArgoCD
   - ArgoCD Application created: `prospectf500-app1-argo-dev`

---

## 🚀 Next Steps: Deploy the Application

### Step 1: Run Infrastructure Workflow (if not done)

The infrastructure workflow now includes a 4th job: **"Setup ArgoCD Application"**

This job will:
- Register the workload cluster with ArgoCD
- Create the ArgoCD Application manifest

**Action Required:**
1. Go to: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-infra.yaml
2. Click "Run workflow" (if not already run with the new job)
3. Select:
   - Branch: `prospectf500-app1-opsera`
   - Action: `apply`
4. Verify all **4 jobs** complete:
   - ✅ Terraform Infrastructure
   - ✅ Install ArgoCD
   - ✅ Install ExternalDNS
   - ✅ **Setup ArgoCD Application** (NEW)

---

### Step 2: Build and Deploy Application

Once the infrastructure workflow completes with all 4 jobs green:

1. **Go to Deployment Workflow:**
   - https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-deploy.yaml

2. **Click "Run workflow"**

3. **Select:**
   - Branch: `prospectf500-app1-opsera`
   - (No additional inputs needed)

4. **Monitor the workflow:**
   The deployment workflow will:
   - Build Docker images for backend and frontend
   - Push images to ECR
   - Update Kubernetes manifests with new image tags
   - ArgoCD will automatically sync and deploy to workload cluster

---

### Step 3: Verify Deployment

#### Check ArgoCD Sync Status

```bash
# Connect to ArgoCD cluster
aws eks update-kubeconfig --name prospectf500-app1-cd --region eu-north-1

# Check application status
kubectl get application prospectf500-app1-argo-dev -n argocd

# Check sync status
kubectl describe application prospectf500-app1-argo-dev -n argocd
```

**Expected Status:**
- `Sync Status`: `Synced`
- `Health Status`: `Healthy`

#### Check Application Pods

```bash
# Connect to workload cluster
aws eks update-kubeconfig --name prospectf500-app1-wrk-dev --region eu-north-1

# Check pods
kubectl get pods -n prospectf500-app1-dev

# Check services
kubectl get svc -n prospectf500-app1-dev

# Check ingress
kubectl get ingress -n prospectf500-app1-dev
```

**Expected Output:**
```
NAME                                      READY   STATUS    RESTARTS   AGE
prospectf500-app1-backend-xxxxx           1/1     Running   0          2m
prospectf500-app1-frontend-xxxxx          1/1     Running   0          2m
```

#### Verify Application Endpoint

After ExternalDNS creates the DNS record (may take 2-5 minutes):

**URL:** https://prospectf500-app1-opsera.agents.opsera-labs.com

Test the endpoint:
```bash
curl https://prospectf500-app1-opsera.agents.opsera-labs.com
```

---

## 📋 Deployment Workflow Details

The `prospectf500-app1-deploy.yaml` workflow includes:

### Job 1: Build and Push Images
- Builds backend Docker image
- Builds frontend Docker image
- Pushes to ECR repositories
- Tags images with git SHA

### Job 2: Update K8s Manifests
- Updates `kustomization.yaml` with new image tags
- Commits changes to Git (triggers ArgoCD sync)

### Job 3: Deploy to Workload Cluster
- Verifies workload cluster exists
- Applies Kustomize overlays
- Waits for deployments to be ready

### Job 4: Verify Endpoint
- Checks if application endpoint is accessible
- Validates health check endpoints

---

## 🔍 Monitoring and Troubleshooting

### If Deployment Fails:

1. **Check Deployment Workflow Logs:**
   - Go to: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-deploy.yaml
   - Check which job failed
   - Read error messages

2. **Common Issues:**

   **Build fails:**
   - Check Dockerfile syntax
   - Verify dependencies in requirements.txt / package.json

   **Image push fails:**
   - Verify ECR repositories exist
   - Check AWS credentials in GitHub Secrets

   **Deployment fails:**
   - Check ArgoCD sync status
   - Verify workload cluster is accessible
   - Check pod logs: `kubectl logs -n prospectf500-app1-dev <pod-name>`

   **Endpoint not accessible:**
   - Check ExternalDNS logs: `kubectl logs -n kube-system -l app=external-dns`
   - Verify Route53 hosted zone exists
   - Check ingress configuration

3. **Check ArgoCD UI:**
   - Port-forward ArgoCD server:
     ```bash
     kubectl port-forward svc/argocd-server -n argocd 8080:443
     ```
   - Access: https://localhost:8080
   - Login with admin password (from infrastructure workflow logs)

---

## 📊 Expected Timeline

- **Infrastructure Setup:** ~10-15 minutes (already done ✅)
- **ArgoCD Application Setup:** ~2-3 minutes (new job)
- **Build and Push Images:** ~5-10 minutes
- **ArgoCD Sync:** ~1-2 minutes
- **DNS Propagation:** ~2-5 minutes
- **Total:** ~20-30 minutes from start to accessible endpoint

---

## ✅ Success Criteria

Your deployment is successful when:

1. ✅ All 4 infrastructure workflow jobs are green
2. ✅ Deployment workflow completes successfully
3. ✅ ArgoCD Application shows `Synced` and `Healthy`
4. ✅ Pods are running in workload cluster
5. ✅ Application endpoint is accessible
6. ✅ Health check endpoints return 200 OK

---

## 🎯 Quick Reference

**Workflow Links:**
- Infrastructure: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-infra.yaml
- Deployment: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-deploy.yaml

**Cluster Names:**
- ArgoCD: `prospectf500-app1-cd`
- Workload: `prospectf500-app1-wrk-dev`

**Application:**
- Name: `prospectf500-app1-argo-dev`
- Namespace: `prospectf500-app1-dev`
- Endpoint: https://prospectf500-app1-opsera.agents.opsera-labs.com

---

**Ready to deploy?** Run the deployment workflow! 🚀
