# Infrastructure & Cluster Verification Status

## Quick Status Check

**Check GitHub Actions Workflow:**
- Go to: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-infra.yaml
- Look for the latest run with action: `apply`
- Verify all 3 jobs completed successfully:
  - ✅ `terraform` (Terraform Infrastructure)
  - ✅ `install-argocd` (Install ArgoCD)
  - ✅ `install-externaldns` (Install ExternalDNS)

---

## Detailed Verification Checklist

### Phase 1: Terraform Infrastructure ✅

**Expected Resources:**
- [ ] VPC: `prospectf500-app1-vpc`
- [ ] ArgoCD Cluster: `prospectf500-app1-argocd`
- [ ] Workload Cluster: `prospectf500-app1-workload-dev`
- [ ] ECR Backend: `prospectf500-app1-backend`
- [ ] ECR Frontend: `prospectf500-app1-frontend`
- [ ] IAM Role: `prospectf500-app1-external-dns`
- [ ] S3 Backend: `prospectf500-app1-tfstate`
- [ ] DynamoDB Lock: `prospectf500-app1-tfstate-lock`

**Verification Commands (via GitHub Actions):**
```bash
# These commands are run in the workflow - check workflow logs
aws eks list-clusters --region eu-north-1 | grep prospectf500-app1
aws ecr describe-repositories --region eu-north-1 | grep prospectf500-app1
aws iam get-role --role-name prospectf500-app1-external-dns --region eu-north-1
```

**Status:** Check workflow logs for "Terraform Infrastructure" job

---

### Phase 2: ArgoCD Installation ✅

**Expected Resources:**
- [ ] ArgoCD namespace exists
- [ ] ArgoCD server deployment running
- [ ] ArgoCD pods in `Running` state

**Verification Commands (via GitHub Actions):**
```bash
# These commands are run in the workflow - check workflow logs
kubectl get namespace argocd
kubectl get pods -n argocd
kubectl get deployment argocd-server -n argocd
```

**Status:** Check workflow logs for "Install ArgoCD" job

**Expected Output:**
```
NAME                            READY   STATUS    RESTARTS   AGE
argocd-application-controller   1/1     Running   0          5m
argocd-repo-server              1/1     Running   0          5m
argocd-server                   1/1     Running   0          5m
```

---

### Phase 3: ExternalDNS Installation ✅

**Expected Resources:**
- [ ] ExternalDNS ServiceAccount with IRSA annotation
- [ ] ExternalDNS ClusterRole and ClusterRoleBinding
- [ ] ExternalDNS Deployment running

**Verification Commands (via GitHub Actions):**
```bash
# These commands are run in the workflow - check workflow logs
kubectl get serviceaccount external-dns -n kube-system
kubectl get deployment external-dns -n kube-system
kubectl get pods -n kube-system -l app=external-dns
```

**Status:** Check workflow logs for "Install ExternalDNS" job

**Expected Output:**
```
NAME                          READY   STATUS    RESTARTS   AGE
external-dns-xxxxxxxxx-xxxxx   1/1     Running   0          3m
```

---

## Manual Verification (If Needed)

If you need to verify manually (requires AWS CLI and kubectl configured):

### 1. Check EKS Clusters
```bash
aws eks list-clusters --region eu-north-1 --query 'clusters[?contains(@, `prospectf500-app1`)]'
```

**Expected:**
- `prospectf500-app1-argocd`
- `prospectf500-app1-workload-dev`

### 2. Check Cluster Status
```bash
aws eks describe-cluster --name prospectf500-app1-argocd --region eu-north-1 --query 'cluster.status'
aws eks describe-cluster --name prospectf500-app1-workload-dev --region eu-north-1 --query 'cluster.status'
```

**Expected:** `ACTIVE`

### 3. Check ECR Repositories
```bash
aws ecr describe-repositories --region eu-north-1 --query 'repositories[?contains(repositoryName, `prospectf500-app1`)].repositoryName'
```

**Expected:**
- `prospectf500-app1-backend`
- `prospectf500-app1-frontend`

### 4. Check IAM Role
```bash
aws iam get-role --role-name prospectf500-app1-external-dns --query 'Role.RoleName'
```

**Expected:** `prospectf500-app1-external-dns`

### 5. Check ArgoCD (if kubectl configured)
```bash
aws eks update-kubeconfig --name prospectf500-app1-argocd --region eu-north-1
kubectl get pods -n argocd
```

### 6. Check ExternalDNS (if kubectl configured)
```bash
aws eks update-kubeconfig --name prospectf500-app1-workload-dev --region eu-north-1
kubectl get pods -n kube-system -l app=external-dns
```

---

## Next Steps After Infrastructure is Ready

Once all 3 jobs are ✅ complete:

1. **Create ArgoCD Application** (if not already done):
   ```bash
   # Connect to ArgoCD cluster
   aws eks update-kubeconfig --name prospectf500-app1-argocd --region eu-north-1
   
   # Apply ArgoCD Application
   kubectl apply -f prospectf500-app1-opsera/argocd/application.yaml
   ```

2. **Run Deployment Workflow**:
   - Go to: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-deploy.yaml
   - Click "Run workflow"
   - Select branch: `prospectf500-app1-opsera`
   - Click "Run workflow"

3. **Monitor Deployment**:
   - Watch the deploy workflow progress
   - Check ArgoCD sync status
   - Verify endpoint: https://prospectf500-app1-dev.agents.opsera-labs.com

---

## Troubleshooting

### If Infrastructure Workflow Failed:

1. **Check Terraform Job Logs:**
   - Look for specific error messages
   - Common issues:
     - VPC limit exceeded
     - IAM role already exists (should be imported)
     - ECR repo already exists (should be imported)

2. **Check ArgoCD Installation:**
   - Verify cluster is ACTIVE before installation
   - Check for timeout errors
   - Verify kubectl access

3. **Check ExternalDNS Installation:**
   - Verify IAM role exists
   - Check IRSA annotation on ServiceAccount
   - Verify cluster is ACTIVE

### If Workflow Not Running:

1. **Check if workflow was triggered:**
   - Go to Actions tab
   - Look for "prospectf500-app1 Infrastructure" workflow
   - Verify it was run with `apply` action

2. **Manually trigger if needed:**
   - Go to: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-infra.yaml
   - Click "Run workflow"
   - Select branch: `prospectf500-app1-opsera`
   - Action: `apply`
   - Click "Run workflow"

---

**Last Updated:** $(date)
**Region:** eu-north-1
**App Identifier:** prospectf500-app1
**Environment:** dev
