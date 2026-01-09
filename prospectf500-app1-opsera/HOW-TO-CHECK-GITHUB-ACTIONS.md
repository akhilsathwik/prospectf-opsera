# How to Check GitHub Actions Output

Since I cannot directly access GitHub Actions, here's a step-by-step guide to check the status yourself:

## 🚀 Quick Steps

### Step 1: Open GitHub Actions
1. Go to: **https://github.com/akhilsathwik/prospectf-opsera/actions**
2. You'll see a list of workflow runs

### Step 2: Find Latest Deployment Run
1. Look for: **"prospectf500-app1 Deploy"** workflow
2. Click on the **latest run** (top of the list)
3. It will show the run number (e.g., "#23")

### Step 3: Check Key Information

#### A. LoadBalancer URL
1. Find the job: **"Deploy to Workload Cluster"**
2. Expand it and find the step: **"Get deployment status"**
3. Look for output like:
   ```
   ✓ LoadBalancer ready!
   ELB URL: http://xxxxx-xxxxx.elb.eu-north-1.amazonaws.com
   ```
4. **Copy this URL** - this is your immediate access point!

#### B. DNS Status
1. Find the job: **"Check DNS and ExternalDNS Status"**
2. Expand it and find the step: **"Check Route53 DNS Record"**
3. Look for:
   - ✅ `DNS record EXISTS` (if created)
   - ⚠️ `DNS record NOT found` (if still pending)

#### C. ExternalDNS Status
1. In the same **"Check DNS and ExternalDNS Status"** job
2. Find the step: **"Check ExternalDNS Status"**
3. Check:
   - ExternalDNS pod status (should be Running)
   - ExternalDNS logs (look for "Successfully created" or errors)

#### D. Pod Status
1. In the **"Deploy to Workload Cluster"** job
2. Find the step: **"Check pod status and events"**
3. Check:
   - Pod status (should be Running)
   - Any errors or warnings

#### E. Endpoint Verification
1. Find the job: **"Verify Endpoint (Fix #83: Mandatory)"**
2. Check the output:
   - ✅ Shows LoadBalancer URL (works immediately)
   - ⏳ Shows DNS endpoint status (may be pending)

## 📊 What to Look For

### ✅ Healthy Deployment
- **All jobs**: Green checkmarks (✓)
- **LoadBalancer**: Has a URL (not `<pending>`)
- **Pods**: Status shows `Running`
- **DNS**: Either exists or shows "still pending" (normal)

### ⚠️ Issues
- **Red X**: Job failed - click to see error details
- **Yellow circle**: Job in progress - wait for completion
- **LoadBalancer pending**: Wait 2-5 minutes
- **Pods not running**: Check pod logs for errors

## 🔍 Specific Information to Find

### 1. LoadBalancer URL
**Where**: `Deploy to Workload Cluster` → `Get deployment status` step

**Look for**:
```
=== LoadBalancer URL ===
✓ LoadBalancer ready!
ELB URL: http://a1b2c3d4e5f6g7h8-1234567890.elb.eu-north-1.amazonaws.com
```

### 2. DNS Record Status
**Where**: `Check DNS and ExternalDNS Status` → `Check Route53 DNS Record` step

**Look for**:
```
✓ DNS record EXISTS for prospectf500-app1-dev.agents.opsera-labs.com
```
OR
```
⚠ DNS record NOT found for prospectf500-app1-dev.agents.opsera-labs.com
```

### 3. ExternalDNS Logs
**Where**: `Check DNS and ExternalDNS Status` → `Check ExternalDNS Status` step

**Look for**:
```
Creating DNS record: prospectf500-app1-dev.agents.opsera-labs.com
Successfully created DNS record
```

### 4. Pod Status
**Where**: `Deploy to Workload Cluster` → `Check pod status and events` step

**Look for**:
```
NAME                                    READY   STATUS    RESTARTS   AGE
prospectf500-app1-backend-xxxxx         1/1     Running   0          5m
prospectf500-app1-frontend-xxxxx         1/1     Running   0          5m
```

## 🛠️ Alternative: Use GitHub API Script

I've created a PowerShell script that can fetch this information via GitHub API:

```powershell
# Set your GitHub token
$env:GITHUB_TOKEN = "your-github-token"

# Run the script
.\prospectf500-app1-opsera\check-github-actions.ps1
```

**To get a GitHub token:**
1. Go to: https://github.com/settings/tokens
2. Click: "Generate new token (classic)"
3. Select scope: `actions:read`
4. Generate and copy the token

## 📝 Quick Checklist

When checking the workflow, look for:

- [ ] **Workflow Status**: Green checkmark (success) or Red X (failure)
- [ ] **LoadBalancer URL**: Found in "Get deployment status" step
- [ ] **DNS Status**: Check "Check Route53 DNS Record" step
- [ ] **ExternalDNS**: Check "Check ExternalDNS Status" step
- [ ] **Pods**: Check "Check pod status and events" step
- [ ] **Endpoint**: Check "Verify Endpoint" job

## 🎯 Most Important: LoadBalancer URL

**The LoadBalancer URL is the most important piece of information!**

Once you find it, you can:
1. Access your app immediately at: `http://<loadbalancer-hostname>`
2. Don't need to wait for DNS
3. Works right away

## 💡 Pro Tip

**Bookmark this URL** for quick access:
```
https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-deploy.yaml
```

This takes you directly to the deployment workflow runs.

---

**Need help?** Share the output from any step and I can help interpret it!
