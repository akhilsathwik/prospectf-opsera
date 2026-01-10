# Deployment Context: your-username

## Configuration Summary

| Input | Value |
|-------|-------|
| Tenant Name | opsera-se |
| Application Name | your-username |
| Environment | dev |
| AWS Region | us-west-2 |

## Resource Names (Short Convention)

| Resource | Pattern | Value |
|----------|---------|-------|
| VPC | opsera-vpc (hardcoded) | opsera-vpc |
| ArgoCD Cluster | argocd-{region_short} | argocd-usw2 |
| Workload Cluster | {tenant_short}-{region_short}-{env_short} | opsera-usw2-np |
| ECR Backend | {tenant}/{app}-backend | opsera-se/your-username-backend |
| ECR Frontend | {tenant}/{app}-frontend | opsera-se/your-username-frontend |
| Namespace | {app}-{env} | your-username-dev |
| ArgoCD App | {app}-{env} | your-username-dev |
| Branch | {app}-deploy | your-username-deploy |

## Deployment Type

**Greenfield** - All infrastructure will be created from scratch.

## Architecture

```
Region: us-west-2

┌─────────────────────────────────────────────────────────────────────┐
│                     ARGOCD CLUSTER (Shared)                         │
│                     argocd-usw2                                     │
├─────────────────────────────────────────────────────────────────────┤
│  Manages ALL workload clusters in us-west-2 region                 │
│  - Tenant agnostic                                                  │
│  - One per region                                                   │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ manages
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   WORKLOAD CLUSTER (Tenant-specific)               │
│                   opsera-usw2-np                                    │
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

### Step 1: Trigger Deployment Workflow

1. Go to GitHub Actions → "Deploy to AWS EKS"
2. Click "Run workflow"
3. Use default inputs (or customize):
   - Tenant: `opsera-se`
   - App Name: `your-username`
   - Environment: `dev`
   - Region: `us-west-2`
4. Click "Run workflow"

**Expected Duration**: 20-30 minutes (infrastructure creation + application deployment)

### What the Workflow Does

#### Phase 1: Infrastructure
- Creates VPC with public/private subnets (if not exists)
- Creates ArgoCD EKS cluster: `argocd-usw2` (if not exists)
- Creates Workload EKS cluster: `opsera-usw2-np` (if not exists)
- Creates ECR repositories for backend and frontend
- Creates OIDC provider for IRSA support
- Installs ArgoCD on ArgoCD cluster
- Sets up Terraform state backend (S3 + DynamoDB)

#### Phase 2: Application
- Builds Docker images for backend and frontend
- Pushes images to ECR with both SHA and `latest` tags (Learning #134)
- Updates Kubernetes manifests with image references
- Commits changes to `your-username-deploy` branch

#### Phase 3: Verification
- Creates AWS credentials secret for IRSA fallback (Learning #139)
- Applies ArgoCD application manifest
- Waits for ArgoCD sync
- Verifies pods are running
- Verifies endpoint responds with HTTP 200

## Key Features (v1.10.0)

### Learning #134: Dual Image Tagging
Images are tagged with BOTH commit SHA and `latest`:
```bash
docker tag $ECR_REGISTRY/$ECR_REPO:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPO:latest
docker push $ECR_REGISTRY/$ECR_REPO:latest
```

### Learning #135: HTTPS Support
Frontend service configured with:
- Port 443 for HTTPS
- ACM certificate annotations (ready for certificate)
- Backend protocol: TCP

### Learning #139: AWS Credentials Secret
Backend deployment includes AWS credentials as environment variables (IRSA fallback):
```yaml
env:
  - name: AWS_ACCESS_KEY_ID
    valueFrom:
      secretKeyRef:
        name: aws-credentials
        key: AWS_ACCESS_KEY_ID
        optional: true
```

## Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS credentials for EKS/ECR access |
| `AWS_SECRET_ACCESS_KEY` | AWS credentials for EKS/ECR access |

## Troubleshooting

### Infrastructure Creation Fails

- **Issue**: Terraform fails with "resource already exists"
  - **Solution**: Workflow will skip creation if resources exist (idempotent)

### ImagePullBackOff

- **Issue**: Pods stuck in ImagePullBackOff
  - **Solution**: Verify ECR repository URL in `kustomization.yaml` - should NOT contain placeholders
  - Check: `kubectl describe pod <pod-name> -n your-username-dev`
  - Verify images exist: `aws ecr describe-images --repository-name opsera-se/your-username-backend`

### LoadBalancer Pending

- **Issue**: Frontend service stuck in "Pending" state
  - **Solution**: Wait 3-5 minutes for AWS to provision LoadBalancer
  - Check: `kubectl get svc your-username-frontend -n your-username-dev`

### Endpoint Not Accessible

- **Issue**: HTTP 200 verification fails
  - **Solution**: 
    1. Check pod logs: `kubectl logs -n your-username-dev deployment/your-username-frontend`
    2. Verify LoadBalancer DNS resolves: `nslookup <endpoint>`
    3. Check security groups allow traffic on port 80/443

### InvalidIdentityTokenException

- **Issue**: Backend fails with "InvalidIdentityTokenException"
  - **Solution**: AWS credentials secret is created automatically. If issue persists, restart deployment:
    ```bash
    kubectl rollout restart deployment/your-username-backend -n your-username-dev
    ```

## Post-Deployment

### Get Endpoint URL

```bash
aws eks update-kubeconfig --name opsera-usw2-np --region us-west-2
kubectl get svc your-username-frontend -n your-username-dev
```

### Access Application

The endpoint will be available at:
- HTTP: `http://<loadbalancer-hostname>`
- HTTPS: `https://<loadbalancer-hostname>` (after ACM certificate is configured)

### Configure HTTPS (Optional)

1. Request ACM certificate in `us-west-2`
2. Update `frontend-service.yaml` with certificate ARN:
   ```yaml
   annotations:
     service.beta.kubernetes.io/aws-load-balancer-ssl-cert: arn:aws:acm:us-west-2:ACCOUNT:certificate/CERT-ID
   ```

## Files Structure

```
your-username-opsera/
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

---

**Last Updated**: 2026-01-10  
**Version**: v1.10.0  
**Status**: Ready for deployment
