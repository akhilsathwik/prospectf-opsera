# Deployment Context: your-username

## Configuration Summary

| Input | Value |
|-------|-------|
| Tenant Name | opsera-se |
| Application Name | your-username |
| Environment | dev |
| AWS Region | eu-north-1 |

## Auto-derived Resources

| Resource | Pattern | Value |
|----------|---------|-------|
| ArgoCD Cluster | argocd-{region} | argocd-eu-north-1 |
| Workload Cluster | {tenant}-{region}-{cluster_env} | opsera-se-eu-north-1-nonprod |
| ECR Backend | {tenant}/{app}-backend | opsera-se/your-username-backend |
| ECR Frontend | {tenant}/{app}-frontend | opsera-se/your-username-frontend |
| Namespace | {app}-{env} | your-username-dev |
| ArgoCD App | {app}-{env} | your-username-dev |

## Deployment Type

**Greenfield** - All infrastructure will be created from scratch.

## Architecture

```
Region: eu-north-1

┌─────────────────────────────────────────────────────────────────────┐
│                     ARGOCD CLUSTER (Shared)                         │
│                     argocd-eu-north-1                               │
├─────────────────────────────────────────────────────────────────────┤
│  Manages ALL workload clusters in eu-north-1 region                 │
│  - Tenant agnostic                                                  │
│  - One per region                                                   │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ manages
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   WORKLOAD CLUSTER (Tenant-specific)               │
│                   opsera-se-eu-north-1-nonprod                      │
├─────────────────────────────────────────────────────────────────────┤
│  Namespaces:                                                         │
│  └─ your-username-dev                                               │
│     ├─ your-username-backend (Deployment + Service)                │
│     └─ your-username-frontend (Deployment + Service)                │
└─────────────────────────────────────────────────────────────────────┘
```

## Application Stack

- **Backend**: Python 3.11 (FastAPI) - Port 8000
- **Frontend**: Node.js 20 (React/Vite) with Nginx - Port 8080

## Deployment Steps

### Step 1: Create Infrastructure (Greenfield)

1. Go to GitHub Actions → "your-username Infrastructure"
2. Click "Run workflow"
3. Select action: **apply**
4. Branch: **main**
5. Click "Run workflow"

This will create:
- ArgoCD EKS cluster: `argocd-eu-north-1`
- Workload EKS cluster: `opsera-se-eu-north-1-nonprod`
- ECR repositories: `opsera-se/your-username-backend`, `opsera-se/your-username-frontend`
- S3 bucket for Terraform state: `your-username-tfstate`
- DynamoDB table for state locking: `your-username-tfstate-lock`

**Expected Duration**: 15-20 minutes

### Step 2: Configure ArgoCD

After infrastructure is created:

1. Get ArgoCD admin password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

2. Port-forward ArgoCD UI:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

3. Access: https://localhost:8080
   - Username: `admin`
   - Password: (from step 1)

4. Apply ArgoCD Application:
   ```bash
   kubectl apply -f your-username-opsera/argocd/application.yaml
   ```

   **Note**: Update `repoURL` in `application.yaml` with your actual GitHub repository URL.

### Step 3: Deploy Application

1. Go to GitHub Actions → "your-username Deploy"
2. Click "Run workflow"
3. Branch: **main**
4. Click "Run workflow"

This will:
- Build Docker images for backend and frontend
- Push images to ECR
- Run Grype security scan
- Update Kubernetes manifests with image tags
- Deploy to workload cluster
- Verify endpoint is accessible

**Expected Duration**: 10-15 minutes

### Step 4: Verify Deployment

After deployment completes:

1. Check pods:
   ```bash
   aws eks update-kubeconfig --name opsera-se-eu-north-1-nonprod --region eu-north-1
   kubectl get pods -n your-username-dev
   ```

2. Get LoadBalancer endpoint:
   ```bash
   kubectl get svc your-username-frontend -n your-username-dev
   ```

3. Test endpoint:
   ```bash
   ENDPOINT=$(kubectl get svc your-username-frontend -n your-username-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
   curl http://$ENDPOINT
   ```

## Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS credentials for EKS/ECR access |
| `AWS_SECRET_ACCESS_KEY` | AWS credentials for EKS/ECR access |

## Troubleshooting

### Infrastructure Creation Fails

- **Issue**: Terraform fails with "resource already exists"
  - **Solution**: Run infrastructure workflow with `apply` action - it will import existing resources

### ImagePullBackOff

- **Issue**: Pods stuck in ImagePullBackOff
  - **Solution**: Verify ECR repository URL in `kustomization.yaml` - should NOT contain placeholders
  - Check: `kubectl describe pod <pod-name> -n your-username-dev`

### LoadBalancer Pending

- **Issue**: Frontend service stuck in "Pending" state
  - **Solution**: Wait 3-5 minutes for AWS to provision LoadBalancer
  - Check: `kubectl get svc your-username-frontend -n your-username-dev`

### Endpoint Not Accessible

- **Issue**: HTTP 200 verification fails
  - **Solution**: 
    1. Check pod logs: `kubectl logs -n your-username-dev deployment/your-username-frontend`
    2. Verify LoadBalancer DNS resolves: `nslookup <endpoint>`
    3. Check security groups allow traffic on port 80

## Next Steps

1. ✅ Create infrastructure (Step 1)
2. ✅ Configure ArgoCD (Step 2)
3. ✅ Deploy application (Step 3)
4. ✅ Verify deployment (Step 4)
5. 🔄 Set up DNS (optional) - Create Route53 record pointing to LoadBalancer
6. 🔄 Configure monitoring (optional) - Set up CloudWatch metrics
7. 🔄 Set up CI/CD (optional) - Enable automatic deployments on push

## Files Structure

```
your-username-opsera/
├── terraform/
│   ├── main.tf              # Infrastructure definitions
│   ├── variables.tf          # Terraform variables
│   └── .gitignore           # Terraform ignore patterns
├── k8s/
│   ├── base/
│   │   ├── namespace.yaml
│   │   ├── backend-deployment.yaml
│   │   ├── backend-service.yaml
│   │   ├── frontend-deployment.yaml
│   │   ├── frontend-service.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│       └── dev/
│           └── kustomization.yaml
├── argocd/
│   └── application.yaml     # ArgoCD application manifest
└── DEPLOYMENT-CONTEXT.md    # This file
```

## Support

For issues or questions:
1. Check GitHub Actions logs
2. Review troubleshooting section above
3. Check Kubernetes events: `kubectl get events -n your-username-dev --sort-by='.lastTimestamp'`
