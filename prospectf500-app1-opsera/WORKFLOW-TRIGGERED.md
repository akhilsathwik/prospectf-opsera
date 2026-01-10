# Infrastructure Workflow Triggered ✅

## Status

**Workflow Run ID**: `20854180596`  
**Status**: Queued → Running  
**Action**: `apply`  
**Started**: 2026-01-09 13:56:28 UTC

## Monitor Progress

### Option 1: GitHub Web UI (Recommended)
👉 **Direct Link**: https://github.com/akhilsathwik/prospectf-opsera/actions/runs/20854180596

### Option 2: GitHub CLI
```bash
# Watch the workflow run
gh run watch 20854180596

# Check status
gh run view 20854180596

# View logs
gh run view 20854180596 --log
```

## What's Happening

The workflow will:

1. ✅ **Terraform Apply** (~2-3 minutes)
   - Updates the ExternalDNS IAM role trust policy
   - Uses correct OIDC issuer URL format
   - No infrastructure recreation needed (just policy update)

2. ✅ **Install ExternalDNS** (~1 minute)
   - Updates ExternalDNS deployment
   - Verifies pod status

3. ✅ **Setup ArgoCD Application** (~1 minute)
   - Registers workload cluster
   - Applies ArgoCD application manifest

## Expected Timeline

| Step | Duration |
|------|----------|
| Terraform Apply | 2-3 minutes |
| ExternalDNS Installation | 1 minute |
| ArgoCD Setup | 1 minute |
| **Total** | **~4-5 minutes** |

## After Workflow Completes

### 1. Check ExternalDNS Status
```bash
kubectl get pods -n kube-system -l app=external-dns
```
Should show: `STATUS Running` (not CrashLoopBackOff)

### 2. Check ExternalDNS Logs
```bash
kubectl logs -n kube-system -l app=external-dns --tail=20
```
Should show:
- ✅ No "AccessDenied" errors
- ✅ "Successfully created DNS record" (after 1-2 minutes)

### 3. Check DNS Record
```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id Z00814191D1XSXELJVTKT \
  --query "ResourceRecordSets[?Name=='prospectf500-app1-dev.agents.opsera-labs.com.']"
```

### 4. Test DNS Endpoint
After DNS record is created (1-2 minutes), wait for propagation (5-10 minutes), then:
```bash
curl -I https://prospectf500-app1-dev.agents.opsera-labs.com
```

## Troubleshooting

### If Workflow Fails

1. **Check workflow logs** via the GitHub Actions UI
2. **Common issues:**
   - AWS credentials not configured
   - Terraform state locked (retry after a few minutes)
   - Cluster not accessible

### If ExternalDNS Still Fails After Fix

1. **Manually restart ExternalDNS:**
   ```bash
   kubectl delete pod -n kube-system -l app=external-dns
   ```

2. **Check IAM role trust policy:**
   ```bash
   aws iam get-role --role-name prospectf500-app1-external-dns \
     --query 'Role.AssumeRolePolicyDocument' --output json
   ```
   Should show condition key using OIDC issuer URL (not ARN)

3. **Use quick fix script:**
   ```powershell
   .\prospectf500-app1-opsera\fix-externaldns-iam.ps1
   ```

## Current Status

- ✅ Workflow triggered successfully
- ⏳ Waiting for Terraform to update IAM role
- ⏳ ExternalDNS will restart automatically
- ⏳ DNS record will be created (1-2 minutes after ExternalDNS starts)

---

**Next Update**: Check workflow status in 2-3 minutes
