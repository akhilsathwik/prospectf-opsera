# PowerShell script to get LoadBalancer URL
# Requires: AWS CLI and kubectl installed

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Get LoadBalancer URL" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if AWS CLI is installed
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install AWS CLI first:" -ForegroundColor Yellow
    Write-Host "  https://aws.amazon.com/cli/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or use GitHub Actions to get this information:" -ForegroundColor Yellow
    Write-Host "  Check the 'Get deployment status' step in the latest workflow run" -ForegroundColor Cyan
    exit 1
}

# Check if kubectl is installed
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "❌ kubectl not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install kubectl first:" -ForegroundColor Yellow
    Write-Host "  https://kubernetes.io/docs/tasks/tools/" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host "✓ AWS CLI and kubectl found" -ForegroundColor Green
Write-Host ""

# Configure kubectl
Write-Host "Configuring kubectl for workload cluster..." -ForegroundColor Yellow
aws eks update-kubeconfig --name prospectf500-app1-wrk-dev --region eu-north-1

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to configure kubectl" -ForegroundColor Red
    Write-Host "Please check your AWS credentials and cluster name" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ kubectl configured" -ForegroundColor Green
Write-Host ""

# Get LoadBalancer URL
Write-Host "Getting LoadBalancer URL..." -ForegroundColor Yellow
$LB_HOSTNAME = kubectl get svc prospectf500-app1-frontend -n prospectf500-app1-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null

if ([string]::IsNullOrEmpty($LB_HOSTNAME)) {
    Write-Host "⚠ LoadBalancer not ready yet" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Checking service status..." -ForegroundColor Yellow
    kubectl get svc prospectf500-app1-frontend -n prospectf500-app1-dev
    Write-Host ""
    Write-Host "If status shows <pending>, wait 2-5 minutes for AWS to provision the LoadBalancer" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  LOADBALANCER URL" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "LoadBalancer Hostname: $LB_HOSTNAME" -ForegroundColor Cyan
Write-Host ""
Write-Host "Access your application at:" -ForegroundColor Yellow
Write-Host "  http://$LB_HOSTNAME" -ForegroundColor Green
Write-Host ""
Write-Host "Testing connection..." -ForegroundColor Yellow

# Test the endpoint
try {
    $response = Invoke-WebRequest -Uri "http://$LB_HOSTNAME" -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
    Write-Host "✓ Connection successful!" -ForegroundColor Green
    Write-Host "  HTTP Status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "⚠ Connection failed or endpoint not responding yet" -ForegroundColor Yellow
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This might be normal if:" -ForegroundColor Yellow
    Write-Host "  - LoadBalancer was just created (wait 2-5 minutes)" -ForegroundColor Gray
    Write-Host "  - Pods are not ready yet" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Check pod status:" -ForegroundColor Yellow
    Write-Host "  kubectl get pods -n prospectf500-app1-dev" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DNS ENDPOINT STATUS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check DNS
$DOMAIN = "prospectf500-app1-dev.agents.opsera-labs.com"
Write-Host "DNS Endpoint: https://$DOMAIN" -ForegroundColor Cyan
Write-Host ""

try {
    $dnsResult = Resolve-DnsName -Name $DOMAIN -ErrorAction Stop
    Write-Host "✓ DNS resolves to: $($dnsResult[0].IPAddress)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Testing HTTPS endpoint..." -ForegroundColor Yellow
    
    try {
        $httpsResponse = Invoke-WebRequest -Uri "https://$DOMAIN" -TimeoutSec 10 -UseBasicParsing -SkipCertificateCheck -ErrorAction Stop
        Write-Host "✓ HTTPS endpoint working!" -ForegroundColor Green
        Write-Host "  HTTP Status: $($httpsResponse.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "⚠ HTTPS not working (certificate may not be configured)" -ForegroundColor Yellow
        Write-Host "  Try HTTP instead: http://$DOMAIN" -ForegroundColor Cyan
    }
} catch {
    Write-Host "⚠ DNS does not resolve yet" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This is normal - DNS propagation can take 5-10 minutes" -ForegroundColor Gray
    Write-Host "ExternalDNS needs to create the Route53 record first" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Check ExternalDNS status:" -ForegroundColor Yellow
    Write-Host "  kubectl get pods -n kube-system -l app=external-dns" -ForegroundColor Cyan
    Write-Host "  kubectl logs -n kube-system -l app=external-dns --tail=20" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Immediate Access (works now):" -ForegroundColor Yellow
Write-Host "  http://$LB_HOSTNAME" -ForegroundColor Green
Write-Host ""
Write-Host "DNS Endpoint (after DNS propagates):" -ForegroundColor Yellow
Write-Host "  https://$DOMAIN" -ForegroundColor Cyan
Write-Host ""
