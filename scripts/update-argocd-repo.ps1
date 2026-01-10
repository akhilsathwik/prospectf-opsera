# Auto-update ArgoCD application.yaml with current GitHub repository URL
# Usage: .\scripts\update-argocd-repo.ps1

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$ArgoCDApp = Join-Path $RepoRoot "argocd-unified\application.yaml"

# Get GitHub repository URL from git remote
$GitRepoUrl = git -C $RepoRoot config --get remote.origin.url

# Convert SSH URL to HTTPS if needed
if ($GitRepoUrl -match "^git@github\.com:(.+)$") {
    $RepoPath = $Matches[1]
    $GitRepoUrl = "https://github.com/$RepoPath"
}

# Ensure it ends with .git
if (-not $GitRepoUrl.EndsWith(".git")) {
    $GitRepoUrl = "$GitRepoUrl.git"
}

Write-Host "Detected GitHub repository: $GitRepoUrl" -ForegroundColor Cyan
Write-Host "Updating ArgoCD application manifest..." -ForegroundColor Yellow

# Read the file
$Content = Get-Content $ArgoCDApp -Raw

# Replace repoURL line
$Content = $Content -replace "repoURL:.*", "repoURL: $GitRepoUrl"

# Write back
Set-Content -Path $ArgoCDApp -Value $Content -NoNewline

Write-Host "✅ Updated argocd-unified/application.yaml" -ForegroundColor Green
Write-Host ""
Write-Host "Verification:" -ForegroundColor Cyan
Select-String -Path $ArgoCDApp -Pattern "repoURL:"
