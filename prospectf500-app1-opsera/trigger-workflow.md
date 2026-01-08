# How to Trigger Infrastructure Workflow with `action: apply`

## Quick Steps

1. **Open this link in your browser:**
   https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-infra.yaml

2. **Click the "Run workflow" button** (top right, next to "Filter workflow runs")

3. **In the dropdown that appears:**
   - **Branch:** Select `prospectf500-app1-opsera`
   - **Action:** Select `apply` (IMPORTANT: Not "plan"!)
   - Click **"Run workflow"** button

4. **Wait for all 4 jobs to complete:**
   - ✅ Terraform Infrastructure
   - ✅ Install ArgoCD
   - ✅ Install ExternalDNS
   - ✅ Setup ArgoCD Application

---

## Visual Guide

```
┌─────────────────────────────────────────┐
│  prospectf500-app1 Infrastructure      │
│                                         │
│  [Run workflow ▼]  [Filter workflow...] │
└─────────────────────────────────────────┘
              │
              ▼ Click "Run workflow"
┌─────────────────────────────────────────┐
│  Run workflow: prospectf500-app1-infra  │
│                                         │
│  Use workflow from: [prospectf500-app1- │
│                      opsera ▼]          │
│                                         │
│  Action: [apply ▼]  ← SELECT THIS!     │
│    • plan                              │
│    • apply  ← SELECT THIS ONE          │
│    • destroy                           │
│                                         │
│  Branch: [prospectf500-app1-opsera ▼]  │
│                                         │
│         [Cancel]  [Run workflow]       │
└─────────────────────────────────────────┘
```

---

## Alternative: Using GitHub CLI (if installed)

If you have GitHub CLI (`gh`) installed and authenticated:

```bash
gh workflow run prospectf500-app1-infra.yaml \
  --ref prospectf500-app1-opsera \
  --field action=apply
```

---

## What Happens Next

After clicking "Run workflow" with `action: apply`:

1. **Terraform Infrastructure** (5-10 min)
   - Creates/updates AWS resources
   - Creates EKS clusters
   - Creates ECR repositories

2. **Install ArgoCD** (2-3 min)
   - Installs ArgoCD on management cluster
   - Waits for ArgoCD to be ready

3. **Install ExternalDNS** (1-2 min)
   - Installs ExternalDNS on workload cluster
   - Configures IRSA for Route53

4. **Setup ArgoCD Application** (1-2 min)
   - Registers workload cluster with ArgoCD
   - Creates ArgoCD Application manifest

**Total time:** ~10-15 minutes

---

## Verify Success

After the workflow completes, check:

1. All 4 jobs show ✅ green checkmarks
2. No errors in any job logs
3. You can proceed to deployment workflow

---

## Troubleshooting

**If jobs are still skipped:**
- Make sure you selected `action: apply` (not `plan`)
- Check the workflow run details to see which action was used

**If workflow fails:**
- Check the specific job that failed
- Read the error messages in the logs
- Common issues are already documented in VERIFICATION-REPORT.md
