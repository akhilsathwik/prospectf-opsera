# Infrastructure Workflow Monitoring

## Workflow Status

**Run ID**: `20854451756`  
**Status**: Queued → Running  
**Action**: `apply` (fixing ExternalDNS IAM role)  
**Started**: 2026-01-09 14:06:02 UTC

## Direct Links

👉 **View Workflow**: https://github.com/akhilsathwik/prospectf-opsera/actions/runs/20854451756

## What's Being Fixed

### Issue: ExternalDNS IAM Role Trust Policy

**Problem**: ExternalDNS pod cannot assume IAM role due to incorrect trust policy condition key.

**Fix**: Updating trust policy to use OIDC issuer URL instead of OIDC provider ARN.

**Change**:
- ❌ **Before**: `${oidc_provider_arn}:sub` (wrong)
- ✅ **After**: `${oidc_issuer_url}:sub` (correct)

## Workflow Steps

1. ✅ **Terraform Apply** (~2-3 minutes)
   - Updates IAM role trust policy
   - No infrastructure recreation needed

2. ⏳ **Install ExternalDNS** (~1 minute)
   - Updates ExternalDNS deployment
   - Verifies pod status

3. ⏳ **Setup ArgoCD Application** (~1 minute)
   - Registers workload cluster
   - Applies ArgoCD application manifest

## Monitor Progress

### Real-time Monitoring

```bash
# Watch workflow in real-time
gh run watch 20854451756

# Check status
gh run view 20854451756

# View logs
gh run view 20854451756 --log
```

### GitHub Web UI

1. Go to: https://github.com/akhilsathwik/prospectf-opsera/actions/runs/20854451756
2. Click on each job to see detailed logs
3. Watch for:
   - ✅ Terraform apply success
   - ✅ ExternalDNS installation success
   - ✅ No errors in logs

## Expected Timeline

| Time | Step | Status |
|------|------|--------|
| 0:00 | Workflow queued | ✅ Started |
| 0:30 | Terraform init | ⏳ Running |
| 2:00 | Terraform apply | ⏳ Running |
| 3:00 | ExternalDNS install | ⏳ Pending |
| 4:00 | ArgoCD setup | ⏳ Pending |
| 5:00 | Complete | ⏳ Pending |

## After Workflow Completes

### Step 1: Verify IAM Role Update

```bash
# Check trust policy
aws iam get-role --role-name prospectf500-app1-external-dns \
  --query 'Role.AssumeRolePolicyDocument' --output json | jq .
```

**Expected**: Condition key should use OIDC issuer URL (not ARN)

### Step 2: Check ExternalDNS Pod

```bash
# Configure kubectl
aws eks update-kubeconfig --name prospectf500-app1-wrk-dev --region eu-north-1

# Check pod status
kubectl get pods -n kube-system -l app=external-dns
```

**Expected**: `STATUS Running` (not CrashLoopBackOff)

### Step 3: Check ExternalDNS Logs

```bash
# View logs
kubectl logs -n kube-system -l app=external-dns --tail=20
```

**Expected**:
- ✅ No "AccessDenied" errors
- ✅ "Successfully created DNS record" (after 1-2 minutes)

### Step 4: Verify DNS Record

```bash
# Check Route53 record
aws route53 list-resource-record-sets \
  --hosted-zone-id Z00814191D1XSXELJVTKT \
  --query "ResourceRecordSets[?Name=='prospectf500-app1-dev.agents.opsera-labs.com.']"
```

**Expected**: DNS record should appear within 1-2 minutes

### Step 5: Test DNS Endpoint

After DNS record is created, wait 5-10 minutes for propagation:

```bash
# Test DNS resolution
nslookup prospectf500-app1-dev.agents.opsera-labs.com

# Test HTTP endpoint
curl -I https://prospectf500-app1-dev.agents.opsera-labs.com
```

**Expected**: HTTP 200 response

## Troubleshooting

### If Workflow Fails

1. **Check workflow logs** for specific error
2. **Common issues**:
   - Terraform state locked → Wait 2-3 minutes and retry
   - AWS credentials → Verify secrets are configured
   - Cluster not found → Verify cluster exists

### If ExternalDNS Still Fails

1. **Restart ExternalDNS pod**:
   ```bash
   kubectl delete pod -n kube-system -l app=external-dns
   ```

2. **Verify IAM role**:
   ```bash
   aws iam get-role --role-name prospectf500-app1-external-dns \
     --query 'Role.AssumeRolePolicyDocument' --output json
   ```

3. **Use quick fix script**:
   ```powershell
   .\prospectf500-app1-opsera\fix-externaldns-iam.ps1
   ```

## Success Criteria

✅ **Workflow completes successfully**  
✅ **ExternalDNS pod in Running state**  
✅ **No AccessDenied errors in logs**  
✅ **DNS record created in Route53**  
✅ **DNS endpoint accessible via HTTPS**

---

**Last Updated**: 2026-01-09 14:06 UTC  
**Status**: ⏳ Workflow running - monitoring progress
