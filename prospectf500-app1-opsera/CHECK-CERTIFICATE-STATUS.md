# Check ACM Certificate Status

## Current Issue

AWS CLI is not installed locally, so we need alternative methods to check certificate status.

## Method 1: AWS Console (Easiest)

1. **Go to AWS Console**: https://console.aws.amazon.com/acm/home?region=eu-north-1

2. **Look for certificate** with domain: `prospectf500-app1-dev.agents.opsera-labs.com`

3. **Check Status column**:
   - ✅ **ISSUED** = Certificate is ready (proceed to deployment)
   - ⏳ **PENDING_VALIDATION** = Waiting for DNS validation (wait 5-30 minutes)
   - ❌ **VALIDATION_TIMED_OUT** = Validation failed (re-run infrastructure workflow)
   - ❌ **Not found** = Certificate not created yet (run infrastructure workflow)

## Method 2: GitHub Actions Workflow

I'll add a step to the infrastructure workflow to output certificate status automatically.

## Method 3: PowerShell Script (If AWS Tools Installed)

If you have AWS Tools for PowerShell installed:

```powershell
# List certificates
Get-ACMCertificateList -Region eu-north-1 | 
  Where-Object { $_.DomainName -eq "prospectf500-app1-dev.agents.opsera-labs.com" }

# Get certificate details
$cert = Get-ACMCertificateList -Region eu-north-1 | 
  Where-Object { $_.DomainName -eq "prospectf500-app1-dev.agents.opsera-labs.com" }

if ($cert) {
    Get-ACMCertificateDetail -CertificateArn $cert.CertificateArn -Region eu-north-1 | 
      Select-Object Status, DomainName, CertificateArn
}
```

## Method 4: Check via Terraform Output

If Terraform has been applied:

```bash
cd prospectf500-app1-opsera/terraform
terraform output acm_certificate_arn

# Then check status (if AWS CLI available)
aws acm describe-certificate \
  --certificate-arn <CERT_ARN> \
  --region eu-north-1 \
  --query 'Certificate.Status'
```

## Expected Certificate Status Flow

| Step | Status | Action |
|------|--------|--------|
| **Before infrastructure workflow** | ❌ Not found | Run infrastructure workflow |
| **After Terraform apply** | ⏳ PENDING_VALIDATION | Wait for DNS validation |
| **During validation** | ⏳ PENDING_VALIDATION | Wait (5-30 minutes) |
| **After validation** | ✅ ISSUED | Run deployment workflow |
| **After deployment** | ✅ ISSUED | HTTPS should work |

## Quick Status Check Commands

### If AWS CLI is installed:

```bash
# List all certificates
aws acm list-certificates --region eu-north-1

# Check specific certificate
aws acm list-certificates --region eu-north-1 \
  --query "CertificateSummaryList[?DomainName=='prospectf500-app1-dev.agents.opsera-labs.com']"

# Get detailed status
CERT_ARN=$(aws acm list-certificates --region eu-north-1 \
  --query "CertificateSummaryList[?DomainName=='prospectf500-app1-dev.agents.opsera-labs.com'].CertificateArn" \
  --output text)

if [ -n "$CERT_ARN" ]; then
  aws acm describe-certificate \
    --certificate-arn $CERT_ARN \
    --region eu-north-1 \
    --query 'Certificate.[Status,DomainName,IssuedAt]' \
    --output table
else
  echo "Certificate not found - run infrastructure workflow first"
fi
```

## What to Do Based on Status

### Status: Not Found
**Action**: Run infrastructure workflow with `apply` action
- Go to: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-infra.yaml
- Click "Run workflow"
- Select Action: `apply`

### Status: PENDING_VALIDATION
**Action**: Wait for DNS validation (5-30 minutes)
- Check Route53 for validation records
- Wait for status to change to `ISSUED`
- Can check again in 10-15 minutes

### Status: ISSUED
**Action**: Run deployment workflow to configure HTTPS
- Go to: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-deploy.yaml
- Click "Run workflow"
- HTTPS will be configured automatically

### Status: VALIDATION_TIMED_OUT
**Action**: Re-run infrastructure workflow
- Delete old certificate (if needed)
- Run infrastructure workflow with `apply` again

## Next Steps

1. **Check certificate status** using AWS Console (Method 1 - easiest)
2. **If not found**: Run infrastructure workflow
3. **If PENDING_VALIDATION**: Wait and check again
4. **If ISSUED**: Run deployment workflow

---

**Last Updated**: 2026-01-09  
**Recommended Method**: AWS Console (no CLI needed)
