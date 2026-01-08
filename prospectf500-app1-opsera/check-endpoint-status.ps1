# PowerShell script to check endpoint status
# This checks service, LoadBalancer, and DNS status

$REGION = "eu-north-1"
$APP_IDENTIFIER = "prospectf500-app1"
$ENVIRONMENT = "dev"
$WORKLOAD_CLUSTER = "$APP_IDENTIFIER-wrk-$ENVIRONMENT"
$NAMESPACE = "$APP_IDENTIFIER-$ENVIRONMENT"
$DOMAIN = "prospectf500-app1-dev.agents.opsera-labs.com"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Endpoint Status Check" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Domain: $DOMAIN" -ForegroundColor White
Write-Host "Namespace: $NAMESPACE" -ForegroundColor White
Write-Host "Cluster: $WORKLOAD_CLUSTER" -ForegroundColor White
Write-Host ""

# Check if AWS CLI is available
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: AWS CLI not found. Please install AWS CLI first." -ForegroundColor Red
    Write-Host ""
    Write-Host "To check status manually:" -ForegroundColor Yellow
    Write-Host "1. Go to GitHub Actions:" -ForegroundColor White
    Write-Host "   https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-deploy.yaml" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "2. Check the latest deployment run" -ForegroundColor White
    Write-Host "3. Look for 'Check DNS' job output" -ForegroundColor White
    exit 1
}

Write-Host "=== Step 1: Configure kubectl ===" -ForegroundColor Cyan
try {
    aws eks update-kubeconfig --name $WORKLOAD_CLUSTER --region $REGION 2>&1 | Out-Null
    Write-Host "✓ kubectl configured" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to configure kubectl" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Step 2: Check Service and LoadBalancer ===" -ForegroundColor Cyan
try {
    $service = kubectl get svc "$APP_IDENTIFIER-frontend" -n $NAMESPACE -o json 2>&1 | ConvertFrom-Json
    
    if ($service) {
        Write-Host "✓ Service exists: $($service.metadata.name)" -ForegroundColor Green
        Write-Host "  Type: $($service.spec.type)" -ForegroundColor White
        
        $lbHostname = $service.status.loadBalancer.ingress[0].hostname
        if ($lbHostname) {
            Write-Host "✓ LoadBalancer ready: $lbHostname" -ForegroundColor Green
        } else {
            Write-Host "⚠ LoadBalancer still pending..." -ForegroundColor Yellow
            Write-Host "  This is normal - takes 2-5 minutes to provision" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✗ Service not found" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Service not found or error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Step 3: Check Pods ===" -ForegroundColor Cyan
try {
    $pods = kubectl get pods -n $NAMESPACE -o json 2>&1 | ConvertFrom-Json
    
    if ($pods.items) {
        Write-Host "Pods in namespace:" -ForegroundColor White
        foreach ($pod in $pods.items) {
            $status = $pod.status.phase
            $ready = "$($pod.status.containerStatuses[0].ready)/1"
            $color = if ($status -eq "Running" -and $ready -eq "1/1") { "Green" } else { "Yellow" }
            Write-Host "  $($pod.metadata.name): $status ($ready)" -ForegroundColor $color
        }
    } else {
        Write-Host "⚠ No pods found in namespace" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Could not get pods: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Step 4: Check ExternalDNS ===" -ForegroundColor Cyan
try {
    $externalDnsPod = kubectl get pods -n kube-system -l app=external-dns -o jsonpath='{.items[0].metadata.name}' 2>&1
    
    if ($externalDnsPod -and $externalDnsPod -ne "") {
        Write-Host "✓ ExternalDNS pod: $externalDnsPod" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "ExternalDNS logs (last 20 lines):" -ForegroundColor White
        kubectl logs $externalDnsPod -n kube-system --tail=20 2>&1
    } else {
        Write-Host "✗ ExternalDNS pod not found" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Could not check ExternalDNS: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Step 5: Check Route53 DNS Record ===" -ForegroundColor Cyan
try {
    $hostedZones = aws route53 list-hosted-zones --query "HostedZones[?Name=='opsera-labs.com.'].[Id]" --output text 2>&1
    
    if ($hostedZones) {
        $zoneId = $hostedZones -replace '/hostedzone/', ''
        Write-Host "✓ Hosted zone found: $zoneId" -ForegroundColor Green
        
        $dnsRecord = aws route53 list-resource-record-sets --hosted-zone-id $zoneId --query "ResourceRecordSets[?Name=='${DOMAIN}.']" --output json 2>&1 | ConvertFrom-Json
        
        if ($dnsRecord -and $dnsRecord.Count -gt 0) {
            Write-Host "✓ DNS record EXISTS for $DOMAIN" -ForegroundColor Green
            Write-Host "  Record details:" -ForegroundColor White
            $dnsRecord | Format-List
        } else {
            Write-Host "⚠ DNS record NOT found for $DOMAIN" -ForegroundColor Yellow
            Write-Host "  This is normal if:" -ForegroundColor Yellow
            Write-Host "    - LoadBalancer was just created (wait 2-5 min)" -ForegroundColor White
            Write-Host "    - ExternalDNS is still processing (wait 1-2 min)" -ForegroundColor White
            Write-Host "    - DNS propagation in progress (wait 5-10 min)" -ForegroundColor White
        }
    } else {
        Write-Host "⚠ Route53 hosted zone 'opsera-labs.com' not found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠ Could not check Route53: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "If DNS record doesn't exist yet:" -ForegroundColor Yellow
Write-Host "  1. Wait 5-10 minutes for LoadBalancer and DNS" -ForegroundColor White
Write-Host "  2. Check ExternalDNS logs above for errors" -ForegroundColor White
Write-Host "  3. Verify service has LoadBalancer endpoint" -ForegroundColor White
Write-Host ""
Write-Host "For detailed troubleshooting, see:" -ForegroundColor Cyan
Write-Host "  prospectf500-app1-opsera/DNS-TROUBLESHOOTING.md" -ForegroundColor Yellow
