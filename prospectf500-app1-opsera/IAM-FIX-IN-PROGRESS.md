# ExternalDNS IAM Fix - In Progress

## Workflow Triggered ✅

**Action**: Infrastructure workflow triggered to fix ExternalDNS IAM role trust policy

## What's Happening

The workflow will:

1. **Terraform Apply** (~2-3 minutes)
   - Updates the ExternalDNS IAM role trust policy
   - Changes condition key from OIDC provider ARN to OIDC issuer URL
   - No infrastructure recreation needed (just policy update)

2. **Install ExternalDNS** (~1 minute)
   - Updates ExternalDNS deployment
   - Verifies pod status

3. **Setup ArgoCD Application** (~1 minute)
   - Registers workload cluster
   - Applies ArgoCD application manifest

## Monitor Progress

### Option 1: GitHub Web UI (Recommended)
👉 **Direct Link**: Check the latest run in:
https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-infra.yaml

### Option 2: GitHub CLI
```bash
# Watch the latest run
gh run watch

# Check status
gh run list --workflow=prospectf500-app1-infra.yaml --limit 1
```

## Expected Timeline

| Step | Duration | Status |
|------|----------|--------|
| Terraform Apply | 2-3 minutes | ⏳ Running |
| ExternalDNS Installation | 1 minute | ⏳ Pending |
| ArgoCD Setup | 1 minute | ⏳ Pending |
| **Total** | **~4-5 minutes** | ⏳ In Progress |

## After Workflow Completes

### Step 1: Verify ExternalDNS Status

```bash
# Check ExternalDNS pod
kubectl get pods -n kube-system -l app=external-dns
```

**Expected**: `STATUS Running` (not CrashLoopBackOff)

### Step 2: Check ExternalDNS Logs

```bash
# View logs
kubectl logs -n kube-system -l app=external-dns --tail=20
```

**Expected**:
- ✅ No "AccessDenied" errors
- ✅ "Successfully created DNS record" (after 1-2 minutes)

### Step 3: Verify DNS Record

```bash
# Check Route53 record
aws route53 list-resource-record-sets \
  --hosted-zone-id Z00814191D1XSXELJVTKT \
  --query "ResourceRecordSets[?Name=='prospectf500-app1-dev.agents.opsera-labs.com.']"
```

**Expected**: DNS record should appear within 1-2 minutes after ExternalDNS starts

### Step 4: Test DNS Endpoint

After DNS record is created, wait 5-10 minutes for propagation, then:

```bash
# Test DNS resolution
nslookup prospectf500-app1-dev.agents.opsera-labs.com

# Test HTTP endpoint
curl -I https://prospectf500-app1-dev.agents.opsera-labs.com
```

**Expected**: HTTP 200 response

## Troubleshooting

### If Workflow Fails

1. **Check workflow logs** via GitHub Actions UI
2. **Common issues**:
   - AWS credentials not configured
   - Terraform state locked (retry after a few minutes)
   - Cluster not accessible

### If ExternalDNS Still Fails After Fix

1. **Manually restart ExternalDNS**:
   ```bash
   kubectl delete pod -n kube-system -l app=external-dns
   ```

2. **Check IAM role trust policy**:
   ```bash
   aws iam get-role --role-name prospectf500-app1-external-dns \
     --query 'Role.AssumeRolePolicyDocument' --output json
   ```
   Should show condition key using OIDC issuer URL (not ARN)

3. **Use quick fix script**:
   ```powershell
   .\prospectf500-app1-opsera\fix-externaldns-iam.ps1
   ```

## What Changed

### Before (Wrong):
```json
"Condition": {
  "StringEquals": {
    "${oidc_provider_arn}:sub": "system:serviceaccount:kube-system:external-dns"
  }
}
```

### After (Correct):
```json
"Condition": {
  "StringEquals": {
    "${oidc_issuer_url}:sub": "system:serviceaccount:kube-system:external-dns"
  }
}
```

## Current Status

- ✅ Workflow triggered successfully
- ⏳ Waiting for Terraform to update IAM role
- ⏳ ExternalDNS will restart automatically after IAM role update
- ⏳ DNS record will be created (1-2 minutes after ExternalDNS starts)

---

**Next Update**: Check workflow status in 2-3 minutes
