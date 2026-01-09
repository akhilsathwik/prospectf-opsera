# PowerShell script to fix ExternalDNS IAM role trust policy
# This updates the existing IAM role with the correct OIDC issuer URL format

$CLUSTER_NAME = "prospectf500-app1-wrk-dev"
$REGION = "eu-north-1"
$ROLE_NAME = "prospectf500-app1-external-dns"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Fix ExternalDNS IAM Role Trust Policy" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if AWS CLI is installed
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI not found!" -ForegroundColor Red
    Write-Host "Please install AWS CLI first: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}

# Get OIDC issuer URL from cluster
Write-Host "Getting OIDC issuer URL from cluster..." -ForegroundColor Yellow
$ISSUER_URL = aws eks describe-cluster --name $CLUSTER_NAME --region $REGION `
  --query 'cluster.identity.oidc.issuer' --output text

if ([string]::IsNullOrEmpty($ISSUER_URL)) {
    Write-Host "❌ ERROR: Could not get OIDC issuer URL" -ForegroundColor Red
    exit 1
}

Write-Host "✓ OIDC Issuer URL: $ISSUER_URL" -ForegroundColor Green

# Remove https:// prefix for condition key
$ISSUER_HOST = $ISSUER_URL -replace 'https://', ''
Write-Host "✓ OIDC Issuer Host: $ISSUER_HOST" -ForegroundColor Green

# Get OIDC provider ARN
Write-Host ""
Write-Host "Getting OIDC provider ARN..." -ForegroundColor Yellow
$OIDC_PROVIDERS = aws iam list-open-id-connect-providers --output json | ConvertFrom-Json
$OIDC_PROVIDER_ARN = $null

foreach ($provider in $OIDC_PROVIDERS.OpenIDConnectProviderList) {
    if ($provider.Arn -like "*$($ISSUER_HOST.Split('/')[0])*") {
        $OIDC_PROVIDER_ARN = $provider.Arn
        break
    }
}

if ([string]::IsNullOrEmpty($OIDC_PROVIDER_ARN)) {
    Write-Host "⚠ WARNING: Could not find OIDC provider ARN automatically" -ForegroundColor Yellow
    Write-Host "You may need to create the OIDC provider first" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ OIDC Provider ARN: $OIDC_PROVIDER_ARN" -ForegroundColor Green

# Create trust policy JSON
Write-Host ""
Write-Host "Creating updated trust policy..." -ForegroundColor Yellow
$TRUST_POLICY = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Principal = @{
                Federated = $OIDC_PROVIDER_ARN
            }
            Action = "sts:AssumeRoleWithWebIdentity"
            Condition = @{
                StringEquals = @{
                    "$ISSUER_HOST`:sub" = "system:serviceaccount:kube-system:external-dns"
                    "$ISSUER_HOST`:aud" = "sts.amazonaws.com"
                }
            }
        }
    )
} | ConvertTo-Json -Depth 10

$TRUST_POLICY_FILE = "$env:TEMP\trust-policy.json"
$TRUST_POLICY | Out-File -FilePath $TRUST_POLICY_FILE -Encoding utf8
Write-Host "✓ Trust policy created" -ForegroundColor Green

# Update IAM role
Write-Host ""
Write-Host "Updating IAM role: $ROLE_NAME..." -ForegroundColor Yellow
try {
    aws iam update-assume-role-policy `
        --role-name $ROLE_NAME `
        --policy-document "file://$TRUST_POLICY_FILE"
    
    Write-Host "✓ IAM role trust policy updated successfully!" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Failed to update IAM role" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
} finally {
    # Clean up
    Remove-Item -Path $TRUST_POLICY_FILE -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Next Steps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Restart ExternalDNS pod:" -ForegroundColor Yellow
Write-Host "   kubectl delete pod -n kube-system -l app=external-dns" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Check ExternalDNS status:" -ForegroundColor Yellow
Write-Host "   kubectl get pods -n kube-system -l app=external-dns" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Check ExternalDNS logs:" -ForegroundColor Yellow
Write-Host "   kubectl logs -n kube-system -l app=external-dns --tail=20" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. Wait for DNS record creation (1-2 minutes)" -ForegroundColor Yellow
Write-Host ""
