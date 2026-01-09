# PowerShell script to help trigger deployment workflows
# This script provides instructions and can check prerequisites

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  your-username Deployment Helper" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if AWS CLI is available
Write-Host "Checking prerequisites..." -ForegroundColor Yellow
$awsAvailable = $false
if (Get-Command aws -ErrorAction SilentlyContinue) {
    Write-Host "✓ AWS CLI found" -ForegroundColor Green
    $awsAvailable = $true
} else {
    Write-Host "✗ AWS CLI not found (optional - GitHub Actions will use secrets)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DEPLOYMENT STEPS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Step 1: Create Infrastructure" -ForegroundColor Yellow
Write-Host "  → Go to: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/your-username-infra.yaml" -ForegroundColor White
Write-Host "  → Click: 'Run workflow'" -ForegroundColor White
Write-Host "  → Action: apply" -ForegroundColor White
Write-Host "  → Branch: prospectf500-app1-opsera" -ForegroundColor White
Write-Host "  → Click: 'Run workflow' (green button)" -ForegroundColor White
Write-Host "  → Wait: ~15-20 minutes" -ForegroundColor White
Write-Host ""

Write-Host "Step 2: Install ArgoCD (First Time Only)" -ForegroundColor Yellow
Write-Host "  Run these commands after infrastructure is ready:" -ForegroundColor White
Write-Host "    aws eks update-kubeconfig --name argocd-eu-north-1 --region eu-north-1" -ForegroundColor Gray
Write-Host "    kubectl create namespace argocd" -ForegroundColor Gray
Write-Host "    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml" -ForegroundColor Gray
Write-Host "    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd" -ForegroundColor Gray
Write-Host ""

Write-Host "Step 3: Configure ArgoCD Application" -ForegroundColor Yellow
Write-Host "  Run these commands:" -ForegroundColor White
Write-Host "    aws eks update-kubeconfig --name argocd-eu-north-1 --region eu-north-1" -ForegroundColor Gray
Write-Host "    kubectl apply -f your-username-opsera/argocd/application.yaml" -ForegroundColor Gray
Write-Host ""

Write-Host "Step 4: Deploy Application" -ForegroundColor Yellow
Write-Host "  → Go to: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/your-username-deploy.yaml" -ForegroundColor White
Write-Host "  → Click: 'Run workflow'" -ForegroundColor White
Write-Host "  → Branch: prospectf500-app1-opsera" -ForegroundColor White
Write-Host "  → Click: 'Run workflow' (green button)" -ForegroundColor White
Write-Host "  → Wait: ~10-15 minutes" -ForegroundColor White
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  QUICK LINKS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Infrastructure Workflow:" -ForegroundColor Yellow
Write-Host "  https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/your-username-infra.yaml" -ForegroundColor Cyan
Write-Host ""
Write-Host "Deployment Workflow:" -ForegroundColor Yellow
Write-Host "  https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/your-username-deploy.yaml" -ForegroundColor Cyan
Write-Host ""
Write-Host "GitHub Secrets (verify these exist):" -ForegroundColor Yellow
Write-Host "  https://github.com/akhilsathwik/prospectf-opsera/settings/secrets/actions" -ForegroundColor Cyan
Write-Host ""

if ($awsAvailable) {
    Write-Host "Would you like to check AWS credentials? (y/n)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -eq "y" -or $response -eq "Y") {
        Write-Host ""
        Write-Host "Checking AWS identity..." -ForegroundColor Yellow
        aws sts get-caller-identity
    }
}

Write-Host ""
Write-Host "Ready to deploy! Follow the steps above." -ForegroundColor Green
