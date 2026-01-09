# SSL/HTTPS Setup Guide

## Current Status

**HTTP**: ✅ Working  
**HTTPS**: ⏳ SSL Certificate Pending

## Problem Explanation

### Why HTTPS is Not Working

1. **SSL Certificate Not Configured**: The LoadBalancer needs an SSL certificate from AWS Certificate Manager (ACM) to enable HTTPS
2. **Certificate Validation Pending**: ACM certificates require DNS validation, which can take 5-30 minutes
3. **Service Annotation Missing**: The Kubernetes service needs the certificate ARN annotation

### Error You're Seeing

When accessing `https://prospectf500-app1-dev.agents.opsera-labs.com/`:
- Connection fails or times out
- Browser shows "Not secure" or SSL error
- HTTP works fine, but HTTPS doesn't

## Solution Implemented

### 1. ACM Certificate Resource (Terraform)

Added to `terraform/main.tf`:

```terraform
# ACM Certificate for HTTPS
resource "aws_acm_certificate" "app" {
  domain_name       = "${var.app_identifier}-${var.environment}.agents.opsera-labs.com"
  validation_method = "DNS"
}

# DNS validation records
resource "aws_route53_record" "cert_validation" {
  # Creates DNS records for certificate validation
}

# Wait for certificate validation
resource "aws_acm_certificate_validation" "app" {
  certificate_arn = aws_acm_certificate.app.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
```

### 2. Service Configuration

Updated `k8s/base/frontend-service.yaml`:

```yaml
annotations:
  service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "PLACEHOLDER_ACM_CERT_ARN"
  service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
```

### 3. Automatic Certificate Configuration

Added workflow step in `prospectf500-app1-deploy.yaml`:
- Gets certificate ARN from Terraform output
- Checks certificate validation status
- Updates service annotation automatically

## How to Enable HTTPS

### Step 1: Run Infrastructure Workflow

1. Go to GitHub Actions: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-infra.yaml
2. Click "Run workflow"
3. Select:
   - **Action**: `apply`
   - **Branch**: `prospectf500-app1-opsera`
4. Click "Run workflow"

This will:
- Create ACM certificate
- Create DNS validation records
- Wait for certificate validation (5-30 minutes)

### Step 2: Wait for Certificate Validation

Certificate validation typically takes:
- **5-15 minutes**: If DNS records are created automatically
- **15-30 minutes**: If manual DNS validation is needed

You can check status:
```bash
# Get certificate ARN from Terraform
cd prospectf500-app1-opsera/terraform
terraform output acm_certificate_arn

# Check certificate status
aws acm describe-certificate \
  --certificate-arn <CERT_ARN> \
  --region eu-north-1 \
  --query 'Certificate.Status'
```

Status should be `ISSUED` when ready.

### Step 3: Deploy Application (Automatic)

The deployment workflow will automatically:
1. Get certificate ARN from Terraform
2. Check if certificate is validated
3. Update service annotation with certificate ARN
4. LoadBalancer will reconfigure with HTTPS (2-5 minutes)

### Step 4: Verify HTTPS

After deployment completes:

```bash
# Test HTTPS endpoint
curl -I https://prospectf500-app1-dev.agents.opsera-labs.com

# Should return HTTP 200 or 301/302
```

## Manual Configuration (If Needed)

If automatic configuration doesn't work:

### 1. Get Certificate ARN

```bash
cd prospectf500-app1-opsera/terraform
terraform output acm_certificate_arn
```

### 2. Update Service Annotation

```bash
CERT_ARN="arn:aws:acm:eu-north-1:ACCOUNT_ID:certificate/CERT_ID"

kubectl annotate service prospectf500-app1-frontend \
  -n prospectf500-app1-dev \
  service.beta.kubernetes.io/aws-load-balancer-ssl-cert="$CERT_ARN" \
  --overwrite
```

### 3. Restart Service (Force LoadBalancer Update)

```bash
# Delete and recreate service (preserves LoadBalancer)
kubectl delete service prospectf500-app1-frontend -n prospectf500-app1-dev
kubectl apply -f prospectf500-app1-opsera/k8s/base/frontend-service.yaml
```

## Troubleshooting

### Certificate Status: PENDING_VALIDATION

**Cause**: DNS validation records not created or not propagated

**Fix**:
1. Check Route53 for validation records:
   ```bash
   aws route53 list-resource-record-sets \
     --hosted-zone-id <ZONE_ID> \
     --query "ResourceRecordSets[?Type=='CNAME']"
   ```

2. If records missing, Terraform may need to be re-run:
   ```bash
   cd prospectf500-app1-opsera/terraform
   terraform apply
   ```

### Certificate Status: VALIDATION_TIMED_OUT

**Cause**: DNS validation took too long (>72 hours)

**Fix**: Delete and recreate certificate:
```bash
# Delete old certificate
aws acm delete-certificate --certificate-arn <CERT_ARN> --region eu-north-1

# Re-run Terraform apply
```

### HTTPS Still Not Working After Configuration

**Check**:
1. Certificate status is `ISSUED`:
   ```bash
   aws acm describe-certificate --certificate-arn <CERT_ARN> --region eu-north-1
   ```

2. Service annotation is correct:
   ```bash
   kubectl get service prospectf500-app1-frontend \
     -n prospectf500-app1-dev \
     -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-ssl-cert}'
   ```

3. LoadBalancer has HTTPS listener:
   ```bash
   LB_ARN=$(aws elbv2 describe-load-balancers \
     --region eu-north-1 \
     --query "LoadBalancers[?DNSName==\`<LB_HOSTNAME>\`].LoadBalancerArn" \
     --output text)
   
   aws elbv2 describe-listeners \
     --load-balancer-arn $LB_ARN \
     --region eu-north-1
   ```

4. Wait 5-10 minutes for LoadBalancer to reconfigure

### Certificate in Wrong Region

**Issue**: ACM certificate must be in the same region as the LoadBalancer

**Fix**: Ensure certificate is created in `eu-north-1` (your region)

## Expected Timeline

| Step | Duration | Status |
|------|----------|--------|
| Run Terraform apply | 2-5 minutes | Creates certificate |
| DNS validation | 5-30 minutes | Automatic via Route53 |
| Certificate issued | Immediate after validation | Status: ISSUED |
| Deploy workflow | 5-10 minutes | Configures service |
| LoadBalancer reconfig | 2-5 minutes | Enables HTTPS |
| **Total** | **15-50 minutes** | HTTPS working |

## Summary

**Current State**:
- ✅ HTTP working
- ⏳ HTTPS pending (certificate validation)

**What's Been Done**:
- ✅ ACM certificate resource added to Terraform
- ✅ Service configured for SSL
- ✅ Automatic certificate configuration in workflow

**Next Steps**:
1. Run infrastructure workflow (`apply` action)
2. Wait for certificate validation (5-30 minutes)
3. Run deployment workflow (will auto-configure HTTPS)
4. Verify HTTPS endpoint

**After Setup**:
- ✅ HTTP: `http://prospectf500-app1-dev.agents.opsera-labs.com/`
- ✅ HTTPS: `https://prospectf500-app1-dev.agents.opsera-labs.com/`

---

**Last Updated**: 2026-01-09  
**Status**: SSL setup configured, pending certificate validation
