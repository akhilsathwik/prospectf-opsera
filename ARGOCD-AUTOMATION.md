# ArgoCD Application Repository URL Automation

## Overview

The ArgoCD application repository URL is now **automatically detected and updated** - no manual configuration needed!

## How It Works

### 1. **Workflow Auto-Update** (Primary Method)

The GitHub Actions workflow automatically updates the ArgoCD application manifest in two phases:

#### Infrastructure Phase
- Runs immediately after checkout
- Detects repository URL from GitHub context: `${{ github.server_url }}/${{ github.repository }}.git`
- Updates `argocd-unified/application.yaml` with the correct URL
- Commits the change if modified

#### Application Phase
- Runs on the deployment branch (`prospectf500-app1-deploy`)
- Ensures the repository URL is correct before deployment
- Updates and commits if needed

**Example Output:**
```
========================================
AUTO-UPDATING ARGOCD APPLICATION
========================================
Detected repository URL: https://github.com/akhilsathwik/prospectf-opsera.git
Updating argocd-unified/application.yaml...
✅ Updated ArgoCD application manifest

Verification:
repoURL: https://github.com/akhilsathwik/prospectf-opsera.git
```

### 2. **Manual Scripts** (Backup Method)

If you need to update the repository URL manually, use the provided scripts:

#### Linux/Mac (Bash)
```bash
./scripts/update-argocd-repo.sh
```

#### Windows (PowerShell)
```powershell
.\scripts\update-argocd-repo.ps1
```

**What the scripts do:**
1. Detect repository URL from `git remote origin`
2. Convert SSH URLs to HTTPS (if needed)
3. Update `argocd-unified/application.yaml`
4. Show verification output

## Current Configuration

**Repository URL**: `https://github.com/akhilsathwik/prospectf-opsera.git`

**File**: `argocd-unified/application.yaml`
```yaml
source:
  repoURL: https://github.com/akhilsathwik/prospectf-opsera.git
  targetRevision: prospectf500-app1-deploy
  path: k8s-unified/overlays/dev
```

## URL Detection Priority

The automation uses the following priority:

1. **GitHub Actions Context** (Workflow)
   - Uses `${{ github.server_url }}/${{ github.repository }}.git`
   - Most reliable in CI/CD environment

2. **Git Remote** (Manual Scripts)
   - Reads from `git config --get remote.origin.url`
   - Converts SSH to HTTPS automatically
   - Works for local development

## Supported URL Formats

The automation handles these formats:

✅ **HTTPS** (Preferred):
```
https://github.com/owner/repo.git
```

✅ **SSH** (Auto-converted):
```
git@github.com:owner/repo.git
→ Converts to: https://github.com/owner/repo.git
```

✅ **Without .git suffix** (Auto-added):
```
https://github.com/owner/repo
→ Converts to: https://github.com/owner/repo.git
```

## Verification

After running the automation, verify the update:

```bash
# Check the updated file
grep "repoURL:" argocd-unified/application.yaml

# Expected output:
# repoURL: https://github.com/akhilsathwik/prospectf-opsera.git
```

## Troubleshooting

### Issue: Repository URL not updating

**Solution**: Check that:
1. Git remote is configured: `git remote -v`
2. File exists: `argocd-unified/application.yaml`
3. Workflow has `contents: write` permission

### Issue: Wrong repository URL

**Solution**: 
1. Update git remote: `git remote set-url origin <correct-url>`
2. Run manual script: `./scripts/update-argocd-repo.sh`
3. Or manually edit `argocd-unified/application.yaml`

### Issue: Script fails on Windows

**Solution**: Use PowerShell script instead:
```powershell
.\scripts\update-argocd-repo.ps1
```

## Benefits

✅ **Zero Manual Configuration** - Repository URL auto-detected  
✅ **Works Across Environments** - GitHub Actions + Local Development  
✅ **SSH/HTTPS Support** - Handles both URL formats  
✅ **Automatic Commits** - Changes committed in workflow  
✅ **Verification Built-in** - Shows updated URL for confirmation  

## Next Steps

1. **Push Branch**: The automation is ready to use
   ```bash
   git push origin prospectf500-app1-deploy
   ```

2. **Trigger Workflow**: The repository URL will be auto-updated during deployment

3. **Verify**: Check the workflow logs to see the auto-update step

---

**Status**: ✅ Fully Automated - No manual configuration needed!
