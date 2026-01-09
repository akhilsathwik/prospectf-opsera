# ExternalDNS IAM Role Fix

## Problem

ExternalDNS pod is in `CrashLoopBackOff` with error:
```
AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity
status code: 403
```

**Root Cause**: The IAM role trust policy uses the wrong condition key format. It's using the OIDC provider ARN instead of the OIDC issuer URL.

## What Was Wrong

**Incorrect (old):**
```json
"Condition": {
  "StringEquals": {
    "${module.workload_cluster.oidc_provider_arn}:sub": "system:serviceaccount:kube-system:external-dns"
  }
}
```

**Correct (new):**
```json
"Condition": {
  "StringEquals": {
    "${replace(oidc_issuer_url, 'https://', '')}:sub": "system:serviceaccount:kube-system:external-dns"
  }
}
```

## Fix Applied

✅ **Terraform configuration updated** - The trust policy now uses the correct OIDC issuer URL format.

## How to Apply the Fix

### Option 1: Update via Terraform (Recommended)

1. **Run Infrastructure Workflow:**
   - Go to: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-infra.yaml
   - Click: "Run workflow"
   - Action: `apply`
   - Branch: `prospectf500-app1-opsera`
   - Click: "Run workflow"

2. **Terraform will:**
   - Update the IAM role trust policy with correct format
   - No infrastructure recreation needed (just policy update)

3. **After Terraform completes:**
   - Restart ExternalDNS pod:
     ```bash
     kubectl delete pod -n kube-system -l app=external-dns
     ```

### Option 2: Manual IAM Role Update (If Terraform Fails)

If you need to fix it manually via AWS Console or CLI:

1. **Get OIDC Issuer URL:**
   ```bash
   aws eks describe-cluster --name prospectf500-app1-wrk-dev --region eu-north-1 \
     --query 'cluster.identity.oidc.issuer' --output text
   ```

2. **Update IAM Role Trust Policy:**
   ```bash
   # Get the issuer URL (example: https://oidc.eks.eu-north-1.amazonaws.com/id/XXXXX)
   ISSUER_URL=$(aws eks describe-cluster --name prospectf500-app1-wrk-dev --region eu-north-1 \
     --query 'cluster.identity.oidc.issuer' --output text)
   
   # Remove https:// prefix
   ISSUER_HOST=$(echo $ISSUER_URL | sed 's|https://||')
   
   # Update trust policy
   aws iam update-assume-role-policy \
     --role-name prospectf500-app1-external-dns \
     --policy-document "{
       \"Version\": \"2012-10-17\",
       \"Statement\": [{
         \"Effect\": \"Allow\",
         \"Principal\": {
           \"Federated\": \"arn:aws:iam::ACCOUNT_ID:oidc-provider/$ISSUER_HOST\"
         },
         \"Action\": \"sts:AssumeRoleWithWebIdentity\",
         \"Condition\": {
           \"StringEquals\": {
             \"$ISSUER_HOST:sub\": \"system:serviceaccount:kube-system:external-dns\",
             \"$ISSUER_HOST:aud\": \"sts.amazonaws.com\"
           }
         }
       }]
     }"
   ```

3. **Restart ExternalDNS:**
   ```bash
   kubectl delete pod -n kube-system -l app=external-dns
   ```

## Verification

After applying the fix:

1. **Check ExternalDNS pod:**
   ```bash
   kubectl get pods -n kube-system -l app=external-dns
   ```
   Should show: `STATUS Running` (not CrashLoopBackOff)

2. **Check ExternalDNS logs:**
   ```bash
   kubectl logs -n kube-system -l app=external-dns --tail=20
   ```
   Should show:
   - ✅ "Successfully created DNS record"
   - ❌ No "AccessDenied" errors

3. **Check DNS record:**
   ```bash
   aws route53 list-resource-record-sets \
     --hosted-zone-id Z00814191D1XSXELJVTKT \
     --query "ResourceRecordSets[?Name=='prospectf500-app1-dev.agents.opsera-labs.com.']"
   ```
   Should show the DNS record exists

## Expected Timeline

| Step | Duration |
|------|----------|
| Terraform apply | 1-2 minutes |
| ExternalDNS pod restart | 30 seconds |
| ExternalDNS creates DNS record | 1-2 minutes |
| DNS propagation | 5-10 minutes |

## Files Changed

1. ✅ `prospectf500-app1-opsera/terraform/main.tf`
   - Added `data "aws_eks_cluster"` to get OIDC issuer URL
   - Fixed trust policy condition key format

## Next Steps

1. ✅ **Terraform fix committed** - Ready to apply
2. ⏳ **Run infrastructure workflow** - Update IAM role
3. ⏳ **Restart ExternalDNS pod** - After IAM role is updated
4. ⏳ **Wait for DNS record** - ExternalDNS will create it automatically

---

**Status**: ✅ Terraform configuration fixed
**Action Required**: Run infrastructure workflow with `action=apply` to update IAM role
**Commit**: `0bc337c` - Fix ExternalDNS IAM role trust policy
