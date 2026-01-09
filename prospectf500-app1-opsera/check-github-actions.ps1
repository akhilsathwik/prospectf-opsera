# PowerShell script to check GitHub Actions workflow status
# Requires: GitHub Personal Access Token with 'actions:read' permission

param(
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    [string]$Repo = "akhilsathwik/prospectf-opsera",
    [string]$Workflow = "prospectf500-app1-deploy.yaml"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GitHub Actions Status Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ([string]::IsNullOrEmpty($GitHubToken)) {
    Write-Host "❌ GitHub token not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please provide a GitHub Personal Access Token:" -ForegroundColor Yellow
    Write-Host "  1. Go to: https://github.com/settings/tokens" -ForegroundColor Cyan
    Write-Host "  2. Generate new token (classic)" -ForegroundColor Cyan
    Write-Host "  3. Select scope: 'actions:read'" -ForegroundColor Cyan
    Write-Host "  4. Run: `$env:GITHUB_TOKEN='your-token'; .\check-github-actions.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or set it as environment variable:" -ForegroundColor Yellow
    Write-Host "  `$env:GITHUB_TOKEN='your-token'" -ForegroundColor Cyan
    exit 1
}

Write-Host "Repository: $Repo" -ForegroundColor Yellow
Write-Host "Workflow: $Workflow" -ForegroundColor Yellow
Write-Host ""

# Get latest workflow run
Write-Host "Fetching latest workflow run..." -ForegroundColor Yellow
$headers = @{
    "Authorization" = "token $GitHubToken"
    "Accept" = "application/vnd.github.v3+json"
}

try {
    # Get workflow runs
    $workflowRunsUrl = "https://api.github.com/repos/$Repo/actions/workflows/$Workflow/runs?per_page=1"
    $runsResponse = Invoke-RestMethod -Uri $workflowRunsUrl -Headers $headers -Method Get
    
    if ($runsResponse.total_count -eq 0) {
        Write-Host "⚠ No workflow runs found" -ForegroundColor Yellow
        exit 0
    }
    
    $latestRun = $runsResponse.workflow_runs[0]
    
    Write-Host "✓ Found latest run: #$($latestRun.run_number)" -ForegroundColor Green
    Write-Host "  Status: $($latestRun.status)" -ForegroundColor $(if ($latestRun.status -eq 'completed') { 'Green' } else { 'Yellow' })
    Write-Host "  Conclusion: $($latestRun.conclusion)" -ForegroundColor $(if ($latestRun.conclusion -eq 'success') { 'Green' } elseif ($latestRun.conclusion -eq 'failure') { 'Red' } else { 'Yellow' })
    Write-Host "  Created: $($latestRun.created_at)" -ForegroundColor Gray
    Write-Host "  URL: $($latestRun.html_url)" -ForegroundColor Cyan
    Write-Host ""
    
    # Get jobs for this run
    Write-Host "Fetching jobs..." -ForegroundColor Yellow
    $jobsUrl = "https://api.github.com/repos/$Repo/actions/runs/$($latestRun.id)/jobs"
    $jobsResponse = Invoke-RestMethod -Uri $jobsUrl -Headers $headers -Method Get
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  JOBS STATUS" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($job in $jobsResponse.jobs) {
        $statusColor = switch ($job.status) {
            'completed' { if ($job.conclusion -eq 'success') { 'Green' } else { 'Red' } }
            'in_progress' { 'Yellow' }
            'queued' { 'Gray' }
            default { 'Yellow' }
        }
        
        Write-Host "$($job.name)" -ForegroundColor $statusColor
        Write-Host "  Status: $($job.status)" -ForegroundColor $statusColor
        Write-Host "  Conclusion: $($job.conclusion)" -ForegroundColor $(if ($job.conclusion -eq 'success') { 'Green' } else { 'Yellow' })
        Write-Host "  URL: $($job.html_url)" -ForegroundColor Cyan
        Write-Host ""
    }
    
    # Try to get specific step outputs
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  LOOKING FOR KEY INFORMATION" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Find "Get deployment status" job
    $deployJob = $jobsResponse.jobs | Where-Object { $_.name -like "*Get deployment status*" -or $_.name -like "*Deploy to Workload Cluster*" }
    
    if ($deployJob) {
        Write-Host "Found deployment job: $($deployJob.name)" -ForegroundColor Green
        Write-Host "  URL: $($deployJob.html_url)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "⚠ To see LoadBalancer URL, check this job's logs:" -ForegroundColor Yellow
        Write-Host "  → Open the job URL above" -ForegroundColor Cyan
        Write-Host "  → Look for 'Get deployment status' step" -ForegroundColor Cyan
        Write-Host "  → It will show: 'ELB URL: http://xxxxx-xxxxx.elb.eu-north-1.amazonaws.com'" -ForegroundColor Cyan
    }
    
    # Find DNS check job
    $dnsJob = $jobsResponse.jobs | Where-Object { $_.name -like "*DNS*" -or $_.name -like "*ExternalDNS*" }
    
    if ($dnsJob) {
        Write-Host ""
        Write-Host "Found DNS check job: $($dnsJob.name)" -ForegroundColor Green
        Write-Host "  URL: $($dnsJob.html_url)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "⚠ To see DNS status, check this job's logs:" -ForegroundColor Yellow
        Write-Host "  → Open the job URL above" -ForegroundColor Cyan
        Write-Host "  → Look for 'Check Route53 DNS Record' step" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  QUICK ACCESS" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "View full workflow run:" -ForegroundColor Yellow
    Write-Host "  $($latestRun.html_url)" -ForegroundColor Cyan
    Write-Host ""
    
} catch {
    Write-Host "❌ Error fetching workflow data: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Make sure:" -ForegroundColor Yellow
    Write-Host "  1. GitHub token has 'actions:read' permission" -ForegroundColor Gray
    Write-Host "  2. Repository name is correct: $Repo" -ForegroundColor Gray
    Write-Host "  3. Workflow file exists: $Workflow" -ForegroundColor Gray
    exit 1
}
