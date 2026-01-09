# Infrastructure & Cluster Diagnosis Report

**Generated**: 2026-01-09  
**Configuration**:
- Tenant: `opsera-se`
- Application: `prospectf500-app1`
- Environment: `dev`
- Region: `eu-north-1`

## Expected Infrastructure

Based on Terraform configuration, the following resources should exist:

### EKS Clusters

| Cluster Type | Expected Name | Purpose |
|--------------|---------------|---------|
| ArgoCD Cluster | `prospectf500-app1-cd` | GitOps management plane |
| Workload Cluster | `prospectf500-app1-wrk-dev` | Application workloads |

### ECR Repositories

| Repository | Expected Name | Purpose |
|------------|---------------|---------|
| Backend | `prospectf500-app1-backend` | Backend container images |
| Frontend | `prospectf500-app1-frontend` | Frontend container images |

### IAM Roles

| Role | Expected Name | Purpose |
|------|---------------|---------|
| ExternalDNS | `prospectf500-app1-external-dns` | Route53 DNS management |

### Kubernetes Resources

| Resource | Expected Name | Namespace |
|----------|---------------|-----------|
| Namespace | `prospectf500-app1-dev` | - |
| Backend Deployment | `prospectf500-app1-backend` | `prospectf500-app1-dev` |
| Frontend Deployment | `prospectf500-app1-frontend` | `prospectf500-app1-dev` |
| Backend Service | `prospectf500-app1-backend` | `prospectf500-app1-dev` |
| Frontend Service | `prospectf500-app1-frontend` | `prospectf500-app1-dev` |

## Issues Identified

### Issue #1: Workflow Cluster Name Mismatch ❌

**Problem**: The infrastructure workflow failed with:
```
ResourceNotFoundException: No cluster found for name: prospectf500-app1-workload-dev
ResourceNotFoundException: No cluster found for name: prospectf500-app1-argocd
```

**Root Cause**: The workflow was looking for:
- `prospectf500-app1-workload-dev` (WRONG)
- `prospectf500-app1-argocd` (WRONG)

But Terraform creates:
- `prospectf500-app1-wrk-dev` (CORRECT)
- `prospectf500-app1-cd` (CORRECT)

**Status**: ✅ **FIXED** - Workflow now uses correct cluster names

### Issue #2: ExternalDNS IAM Role Trust Policy ❌

**Problem**: ExternalDNS pod in `CrashLoopBackOff` with:
```
AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity
status code: 403
```

**Root Cause**: IAM role trust policy uses wrong condition key format:
- **Wrong**: `${oidc_provider_arn}:sub` (using ARN)
- **Correct**: `${oidc_issuer_url}:sub` (using issuer URL)

**Status**: ✅ **FIXED** - Terraform updated to use correct OIDC issuer URL

**Action Required**: Run infrastructure workflow with `action=apply` to update IAM role

### Issue #3: DNS Record Not Created ⚠️

**Problem**: DNS record for `prospectf500-app1-dev.agents.opsera-labs.com` not found

**Root Cause**: ExternalDNS cannot create DNS records due to IAM permission issue (Issue #2)

**Status**: ⏳ **PENDING** - Will be resolved after IAM role is fixed

## Current Status Summary

| Component | Status | Details |
|-----------|--------|---------|
| **Application** | ✅ **WORKING** | Accessible via LoadBalancer URL |
| **LoadBalancer** | ✅ **WORKING** | `http://a4bfb78700763431d9e5a0d0a49032cf-27bdb1e0e7029526.elb.eu-north-1.amazonaws.com/` |
| **Backend Pods** | ✅ **RUNNING** | 2/2 replicas running |
| **Frontend Pods** | ✅ **RUNNING** | 1/1 replica running |
| **ArgoCD Cluster** | ❓ **UNKNOWN** | Need to verify existence |
| **Workload Cluster** | ✅ **EXISTS** | Confirmed from previous deployments |
| **ECR Repositories** | ✅ **EXISTS** | Images successfully pushed |
| **ExternalDNS** | ❌ **FAILING** | CrashLoopBackOff - IAM issue |
| **DNS Record** | ❌ **MISSING** | Not created due to ExternalDNS failure |

## Verification Steps

### Step 1: Verify EKS Clusters

Run this via GitHub Actions or AWS Console:

```bash
# Check ArgoCD cluster
aws eks describe-cluster --name prospectf500-app1-cd --region eu-north-1

# Check Workload cluster
aws eks describe-cluster --name prospectf500-app1-wrk-dev --region eu-north-1

# List all clusters
aws eks list-clusters --region eu-north-1
```

**Expected Output**:
- ✅ `prospectf500-app1-cd` should exist
- ✅ `prospectf500-app1-wrk-dev` should exist

### Step 2: Verify ECR Repositories

```bash
# Check backend repository
aws ecr describe-repositories --repository-names prospectf500-app1-backend --region eu-north-1

# Check frontend repository
aws ecr describe-repositories --repository-names prospectf500-app1-frontend --region eu-north-1
```

**Expected Output**:
- ✅ Both repositories should exist
- ✅ Should contain recent images

### Step 3: Verify IAM Role

```bash
# Check ExternalDNS IAM role
aws iam get-role --role-name prospectf500-app1-external-dns

# Check trust policy
aws iam get-role --role-name prospectf500-app1-external-dns \
  --query 'Role.AssumeRolePolicyDocument' --output json
```

**Expected Output**:
- ✅ Role should exist
- ⚠️ Trust policy should use OIDC issuer URL (not ARN) - **NEEDS UPDATE**

### Step 4: Verify Kubernetes Resources

```bash
# Configure kubectl
aws eks update-kubeconfig --name prospectf500-app1-wrk-dev --region eu-north-1

# Check namespace
kubectl get namespace prospectf500-app1-dev

# Check deployments
kubectl get deployments -n prospectf500-app1-dev

# Check services
kubectl get services -n prospectf500-app1-dev

# Check pods
kubectl get pods -n prospectf500-app1-dev

# Check ExternalDNS
kubectl get pods -n kube-system -l app=external-dns
kubectl logs -n kube-system -l app=external-dns --tail=20
```

**Expected Output**:
- ✅ Namespace exists
- ✅ Backend and frontend deployments running
- ✅ Services configured
- ✅ Pods in Running state
- ❌ ExternalDNS in CrashLoopBackOff (until IAM fixed)

### Step 5: Verify DNS Record

```bash
# Check Route53 record
aws route53 list-resource-record-sets \
  --hosted-zone-id Z00814191D1XSXELJVTKT \
  --query "ResourceRecordSets[?Name=='prospectf500-app1-dev.agents.opsera-labs.com.']"
```

**Expected Output**:
- ❌ Record not found (until ExternalDNS is fixed)

## Recommended Actions

### Priority 1: Fix ExternalDNS IAM Role (CRITICAL)

1. **Run Infrastructure Workflow**:
   - Go to: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-infra.yaml
   - Click: "Run workflow"
   - Action: `apply`
   - Branch: `prospectf500-app1-opsera`
   - Click: "Run workflow"

2. **Wait for Completion** (~2-3 minutes)

3. **Restart ExternalDNS**:
   ```bash
   kubectl delete pod -n kube-system -l app=external-dns
   ```

4. **Verify ExternalDNS**:
   ```bash
   kubectl get pods -n kube-system -l app=external-dns
   kubectl logs -n kube-system -l app=external-dns --tail=20
   ```
   Should show: ✅ Running (no AccessDenied errors)

5. **Wait for DNS Record** (1-2 minutes after ExternalDNS starts)

### Priority 2: Verify All Infrastructure

Run the infrastructure check workflow (once it's available):
- Workflow: `check-infrastructure.yaml`
- This will verify all clusters, ECR repos, IAM roles, and Kubernetes resources

### Priority 3: Test DNS Endpoint

After ExternalDNS creates the DNS record (5-10 minutes for propagation):

```bash
# Test DNS resolution
nslookup prospectf500-app1-dev.agents.opsera-labs.com

# Test HTTP endpoint
curl -I https://prospectf500-app1-dev.agents.opsera-labs.com
```

**Expected**: HTTP 200 response

## Next Steps

1. ✅ **Terraform configuration fixed** (IAM role trust policy)
2. ✅ **Workflow cluster names fixed** (using correct names)
3. ⏳ **Run infrastructure workflow** to apply IAM role fix
4. ⏳ **Verify ExternalDNS** after IAM role update
5. ⏳ **Wait for DNS record** creation
6. ⏳ **Test DNS endpoint** after propagation

## Files Changed

1. ✅ `prospectf500-app1-opsera/terraform/main.tf`
   - Fixed IAM role trust policy to use OIDC issuer URL
   - Commit: `0bc337c`

2. ✅ `.github/workflows/prospectf500-app1-infra.yaml`
   - Already uses correct cluster names
   - Added ExternalDNS diagnostics

3. ✅ `.github/workflows/check-infrastructure.yaml`
   - New workflow for comprehensive infrastructure checks
   - Commit: `259e843`

## Support

If issues persist:
1. Check GitHub Actions logs for detailed error messages
2. Review `EXTERNALDNS-IAM-FIX.md` for IAM troubleshooting
3. Review `DNS-TROUBLESHOOTING-GUIDE.md` for DNS issues

---

**Last Updated**: 2026-01-09  
**Status**: Infrastructure fixes ready, awaiting workflow execution
