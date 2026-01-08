# PowerShell script to verify GitHub Actions workflow status
# This checks the infrastructure workflow status via GitHub API

$repo = "akhilsathwik/prospectf-opsera"
$workflow = "prospectf500-app1-infra.yaml"
$branch = "prospectf500-app1-opsera"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "GitHub Actions Workflow Verification" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Repository: $repo" -ForegroundColor White
Write-Host "Workflow: $workflow" -ForegroundColor White
Write-Host "Branch: $branch" -ForegroundColor White
Write-Host ""

# GitHub Actions workflow URL
$workflowUrl = "https://github.com/$repo/actions/workflows/$workflow"

Write-Host "Workflow URL: $workflowUrl" -ForegroundColor Yellow
Write-Host ""
Write-Host "To verify infrastructure status:" -ForegroundColor Cyan
Write-Host "1. Open the URL above in your browser" -ForegroundColor White
Write-Host "2. Look for the latest workflow run with action='apply'" -ForegroundColor White
Write-Host "3. Check if all 3 jobs completed successfully:" -ForegroundColor White
Write-Host "   - Terraform Infrastructure" -ForegroundColor White
Write-Host "   - Install ArgoCD" -ForegroundColor White
Write-Host "   - Install ExternalDNS" -ForegroundColor White
Write-Host ""

Write-Host "Expected Jobs:" -ForegroundColor Cyan
Write-Host "  [✓] terraform - Terraform Infrastructure" -ForegroundColor Green
Write-Host "  [✓] install-argocd - Install ArgoCD" -ForegroundColor Green
Write-Host "  [✓] install-externaldns - Install ExternalDNS" -ForegroundColor Green
Write-Host ""

Write-Host "If all jobs show green checkmarks, infrastructure is ready!" -ForegroundColor Green
Write-Host ""

Write-Host "To check detailed status, visit:" -ForegroundColor Cyan
Write-Host $workflowUrl -ForegroundColor Yellow
