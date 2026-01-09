# HTTPS Error Explanation - ERR_SSL_PROTOCOL_ERROR

## Current Error

**Error**: `ERR_SSL_PROTOCOL_ERROR`  
**URL**: `https://a4bfb78700763431d9e5a0d0a49032cf-27bdb1e0e7029526.elb.eu-north-1.amazonaws.com`  
**Message**: "This site can't provide a secure connection"

## Why This Error is Happening

### Root Cause

1. **ACM Certificate Not Created Yet**: The SSL certificate hasn't been created because the infrastructure workflow hasn't been run with `apply` action
2. **LoadBalancer Not Configured for HTTPS**: The LoadBalancer doesn't have an SSL certificate attached, so it can't handle HTTPS requests
3. **Direct LoadBalancer URL**: You're accessing the LoadBalancer directly, which won't have a certificate (only the DNS endpoint will)

### What This Means

- ✅ **HTTP works**: `http://a4bfb78700763431d9e5a0d0a49032cf-27bdb1e0e7029526.elb.eu-north-1.amazonaws.com` (no SSL needed)
- ❌ **HTTPS fails**: `https://a4bfb78700763431d9e5a0d0a49032cf-27bdb1e0e7029526.elb.eu-north-1.amazonaws.com` (needs SSL certificate)

## Solution Steps

### Step 1: Create ACM Certificate (Required First)

You need to run the infrastructure workflow to create the ACM certificate:

1. **Go to Infrastructure Workflow**:
   - https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-infra.yaml

2. **Click "Run workflow"**

3. **Select**:
   - **Action**: `apply` (this creates the certificate)
   - **Branch**: `prospectf500-app1-opsera`

4. **Click "Run workflow"**

5. **Wait for completion** (2-5 minutes)

This will:
- Create ACM certificate for `prospectf500-app1-dev.agents.opsera-labs.com`
- Create DNS validation records in Route53
- Wait for certificate validation (5-30 minutes)

### Step 2: Check Certificate Status

After Terraform apply completes, check if certificate is validated:

```bash
# Get certificate ARN from Terraform output
cd prospectf500-app1-opsera/terraform
terraform output acm_certificate_arn

# Check certificate status
aws acm describe-certificate \
  --certificate-arn <CERT_ARN> \
  --region eu-north-1 \
  --query 'Certificate.Status'
```

**Status should be `ISSUED`** before proceeding.

### Step 3: Run Deployment Workflow

Once certificate is validated:

1. **Go to Deployment Workflow**:
   - https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-deploy.yaml

2. **Click "Run workflow"**

3. **Wait for completion** (5-10 minutes)

The workflow will automatically:
- Get certificate ARN from Terraform
- Update service annotation with certificate
- Configure LoadBalancer for HTTPS

### Step 4: Verify HTTPS

After deployment, test:

```bash
# Test DNS endpoint (this will have certificate)
curl -I https://prospectf500-app1-dev.agents.opsera-labs.com

# Should return HTTP 200, 301, or 302
```

**Note**: The direct LoadBalancer URL (`https://a4bfb787...elb.eu-north-1.amazonaws.com`) will **never** have a certificate. Only the DNS endpoint (`https://prospectf500-app1-dev.agents.opsera-labs.com`) will have HTTPS.

## Important Notes

### Direct LoadBalancer URL vs DNS Endpoint

| URL Type | HTTP | HTTPS |
|----------|------|-------|
| **Direct LoadBalancer** | ✅ Works | ❌ Never works (no certificate) |
| **DNS Endpoint** | ✅ Works | ✅ Works (after certificate setup) |

**Always use the DNS endpoint for HTTPS**:
- ✅ `https://prospectf500-app1-dev.agents.opsera-labs.com/`
- ❌ `https://a4bfb787...elb.eu-north-1.amazonaws.com` (no certificate)

### Why Direct LoadBalancer URL Can't Have HTTPS

1. ACM certificates are domain-specific (only for `*.agents.opsera-labs.com`)
2. LoadBalancer hostname is random AWS-generated domain
3. Certificate validation requires DNS control over the domain
4. AWS doesn't provide certificates for ELB hostnames

## Current Status Checklist

- [ ] Infrastructure workflow run with `apply` action?
- [ ] ACM certificate created?
- [ ] Certificate validated (Status: `ISSUED`)?
- [ ] Deployment workflow run after certificate validation?
- [ ] Service annotation updated with certificate ARN?
- [ ] LoadBalancer reconfigured (2-5 minutes after service update)?

## Quick Fix Commands

### Check if Certificate Exists

```bash
aws acm list-certificates --region eu-north-1 \
  --query "CertificateSummaryList[?DomainName=='prospectf500-app1-dev.agents.opsera-labs.com']"
```

### Check Certificate Status

```bash
# Get certificate ARN first
CERT_ARN=$(aws acm list-certificates --region eu-north-1 \
  --query "CertificateSummaryList[?DomainName=='prospectf500-app1-dev.agents.opsera-labs.com'].CertificateArn" \
  --output text)

# Check status
aws acm describe-certificate \
  --certificate-arn $CERT_ARN \
  --region eu-north-1 \
  --query 'Certificate.Status'
```

### Check Service Annotation

```bash
kubectl get service prospectf500-app1-frontend \
  -n prospectf500-app1-dev \
  -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-ssl-cert}'
```

Should show certificate ARN (not empty or `PLACEHOLDER_ACM_CERT_ARN`).

## Expected Timeline

| Step | Duration | Status |
|------|----------|--------|
| Run infrastructure workflow | 2-5 minutes | ⏳ Not done yet |
| Certificate validation | 5-30 minutes | ⏳ Waiting |
| Run deployment workflow | 5-10 minutes | ⏳ Waiting |
| LoadBalancer reconfig | 2-5 minutes | ⏳ Waiting |
| **Total** | **15-50 minutes** | ⏳ Pending |

## Summary

**Error**: `ERR_SSL_PROTOCOL_ERROR`  
**Cause**: ACM certificate not created/configured yet  
**Fix**: 
1. Run infrastructure workflow (`apply` action) to create certificate
2. Wait for certificate validation (5-30 minutes)
3. Run deployment workflow to configure HTTPS
4. Use DNS endpoint (`https://prospectf500-app1-dev.agents.opsera-labs.com/`) not LoadBalancer URL

**Current State**: 
- ✅ HTTP working on both URLs
- ❌ HTTPS not working (certificate pending)

**Next Action**: Run infrastructure workflow with `apply` action

---

**Last Updated**: 2026-01-09  
**Status**: HTTPS pending - certificate needs to be created
