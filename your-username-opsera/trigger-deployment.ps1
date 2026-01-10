# PowerShell script to trigger GitHub Actions workflow
# Run this from the repository root

Write-Host "🚀 Triggering Deployment Workflow" -ForegroundColor Cyan
Write-Host ""

# Check if gh CLI is installed
try {
    $ghVersion = gh --version 2>&1
    Write-Host "✅ GitHub CLI found" -ForegroundColor Green
} catch {
    Write-Host "❌ GitHub CLI not found. Install from: https://cli.github.com/" -ForegroundColor Red
    Write-Host "   Windows: winget install GitHub.cli" -ForegroundColor Yellow
    exit 1
}

# Check if authenticated
try {
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Not authenticated. Running: gh auth login" -ForegroundColor Yellow
        gh auth login
    } else {
        Write-Host "✅ Authenticated with GitHub" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Authentication check failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Triggering workflow with parameters:" -ForegroundColor Cyan
Write-Host "  Tenant: opsera-se"
Write-Host "  App Name: your-username"
Write-Host "  Environment: dev"
Write-Host "  Region: us-west-2"
Write-Host ""

# Trigger workflow
gh workflow run "Deploy to AWS EKS" `
  --ref main `
  -f tenant_name=opsera-se `
  -f app_name=your-username `
  -f app_env=dev `
  -f app_region=us-west-2

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Workflow triggered successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Monitor progress at:" -ForegroundColor Cyan
    Write-Host "  https://github.com/$(gh repo view --json owner,name -q '.owner.login + '/' + .name')/actions" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Expected duration: 30-45 minutes" -ForegroundColor Yellow
    Write-Host "  - Infrastructure: 15-20 min" -ForegroundColor Gray
    Write-Host "  - Application: 10-15 min" -ForegroundColor Gray
    Write-Host "  - Verification: 5-10 min" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "❌ Failed to trigger workflow" -ForegroundColor Red
    Write-Host "Check your GitHub authentication and repository access" -ForegroundColor Yellow
    exit 1
}
