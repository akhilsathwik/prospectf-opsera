# Fix HTTPS Error - Step by Step Guide

## Current Error

**Error**: `ERR_SSL_PROTOCOL_ERROR`  
**URL**: `https://a4bfb78700763431d9e5a0d0a49032cf-27bdb1e0e7029526.elb.eu-north-1.amazonaws.com`  
**Status**: ❌ HTTPS not working

## Why This is Happening

1. **ACM Certificate Not Created**: The SSL certificate hasn't been created yet
2. **Service Has Placeholder**: The service annotation still has `PLACEHOLDER_ACM_CERT_ARN`
3. **Direct LoadBalancer URL**: This URL will **never** have HTTPS - only the DNS endpoint will

## Important: Use DNS Endpoint, Not LoadBalancer URL

| URL | HTTP | HTTPS |
|-----|------|-------|
| **LoadBalancer** (`https://a4bfb787...elb.eu-north-1.amazonaws.com`) | ✅ Works | ❌ **Never works** (no certificate) |
| **DNS Endpoint** (`https://prospectf500-app1-dev.agents.opsera-labs.com`) | ✅ Works | ✅ **Will work** (after certificate) |

**Always use the DNS endpoint for HTTPS!**

## Step-by-Step Fix

### Step 1: Run Infrastructure Workflow (Create Certificate)

1. **Open**: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-infra.yaml

2. **Click**: "Run workflow" button (top right)

3. **Select**:
   - **Action**: `apply` ← **IMPORTANT: Must be 'apply'**
   - **Branch**: `prospectf500-app1-opsera`

4. **Click**: Green "Run workflow" button

5. **Wait**: 2-5 minutes for Terraform to create the certificate

### Step 2: Wait for Certificate Validation

After Step 1 completes:

- **Certificate created**: ✅ (immediate)
- **Certificate validation**: ⏳ 5-30 minutes (automatic via DNS)

You can check status:
```bash
# List certificates
aws acm list-certificates --region eu-north-1

# Check specific certificate status
aws acm describe-certificate \
  --certificate-arn <CERT_ARN> \
  --region eu-north-1 \
  --query 'Certificate.Status'
```

**Wait until status is `ISSUED`** before proceeding.

### Step 3: Run Deployment Workflow (Configure HTTPS)

Once certificate status is `ISSUED`:

1. **Open**: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-deploy.yaml

2. **Click**: "Run workflow"

3. **Wait**: 5-10 minutes

The workflow will automatically:
- ✅ Get certificate ARN from Terraform
- ✅ Update service annotation with certificate ARN
- ✅ Configure LoadBalancer for HTTPS

### Step 4: Test HTTPS (Use DNS Endpoint!)

After deployment completes, test:

```bash
# ✅ CORRECT: Use DNS endpoint
curl -I https://prospectf500-app1-dev.agents.opsera-labs.com

# ❌ WRONG: Don't use LoadBalancer URL (will never work)
curl -I https://a4bfb78700763431d9e5a0d0a49032cf-27bdb1e0e7029526.elb.eu-north-1.amazonaws.com
```

**In Browser**: Use `https://prospectf500-app1-dev.agents.opsera-labs.com/`

## Quick Status Check

### Check if Certificate Exists

```bash
aws acm list-certificates --region eu-north-1 \
  --query "CertificateSummaryList[?DomainName=='prospectf500-app1-dev.agents.opsera-labs.com']"
```

**If empty**: Certificate not created yet → Run Step 1

### Check Certificate Status

```bash
# Get certificate ARN
CERT_ARN=$(aws acm list-certificates --region eu-north-1 \
  --query "CertificateSummaryList[?DomainName=='prospectf500-app1-dev.agents.opsera-labs.com'].CertificateArn" \
  --output text)

# Check status
aws acm describe-certificate \
  --certificate-arn $CERT_ARN \
  --region eu-north-1 \
  --query 'Certificate.Status'
```

**Status should be `ISSUED`** before Step 3.

### Check Service Annotation

```bash
kubectl get service prospectf500-app1-frontend \
  -n prospectf500-app1-dev \
  -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-ssl-cert}'
```

**Should show**: Certificate ARN (not `PLACEHOLDER_ACM_CERT_ARN`)

## Expected Timeline

| Step | Duration | What Happens |
|------|----------|--------------|
| **Step 1**: Run infrastructure workflow | 2-5 min | Creates certificate |
| **Step 2**: Certificate validation | 5-30 min | DNS validation (automatic) |
| **Step 3**: Run deployment workflow | 5-10 min | Configures HTTPS |
| **Step 4**: LoadBalancer reconfig | 2-5 min | Enables HTTPS listener |
| **Total** | **15-50 minutes** | HTTPS working |

## Troubleshooting

### Certificate Status: PENDING_VALIDATION

**Wait longer** - DNS validation can take up to 30 minutes. Check Route53 for validation records.

### Certificate Status: VALIDATION_TIMED_OUT

**Re-run infrastructure workflow** - Certificate validation failed. Delete and recreate.

### Service Still Has Placeholder

**Run deployment workflow again** - The workflow should update it automatically. If not, check workflow logs.

### HTTPS Still Not Working After All Steps

1. **Check certificate status**: Must be `ISSUED`
2. **Check service annotation**: Must have certificate ARN (not placeholder)
3. **Wait 5-10 minutes**: LoadBalancer needs time to reconfigure
4. **Use DNS endpoint**: Not LoadBalancer URL
5. **Check browser cache**: Try incognito/private window

## Summary

**Current Error**: `ERR_SSL_PROTOCOL_ERROR`  
**Cause**: Certificate not created/configured yet  
**Fix**: 
1. ✅ Run infrastructure workflow (`apply`)
2. ⏳ Wait for certificate validation (5-30 min)
3. ✅ Run deployment workflow
4. ✅ Use DNS endpoint for HTTPS

**Important**: 
- ❌ Don't use LoadBalancer URL for HTTPS (will never work)
- ✅ Use DNS endpoint: `https://prospectf500-app1-dev.agents.opsera-labs.com/`

---

**Last Updated**: 2026-01-09  
**Next Action**: Run infrastructure workflow with `apply` action
