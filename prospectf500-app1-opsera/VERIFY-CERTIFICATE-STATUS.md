# Verify Certificate Status - Quick Guide

## How to Check Certificate Status

### Option 1: Check Infrastructure Workflow Output (Recommended)

1. **Go to**: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-infra.yaml

2. **Click on the latest workflow run** (should be the most recent one)

3. **Expand the "Output infrastructure details" step**

4. **Look for this section**:
   ```
   === ACM Certificate Status ===
   Certificate ARN: arn:aws:acm:eu-north-1:...
   Domain: prospectf500-app1-dev.agents.opsera-labs.com
   Status: ISSUED (or PENDING_VALIDATION)
   ```

### Option 2: AWS Console (Visual Check)

1. **Go to**: https://console.aws.amazon.com/acm/home?region=eu-north-1

2. **Look for certificate** with domain: `prospectf500-app1-dev.agents.opsera-labs.com`

3. **Check Status column**:
   - ✅ **ISSUED** = Ready
   - ⏳ **PENDING_VALIDATION** = Waiting
   - ❌ **Not found** = Not created

## What to Do Based on Status

### If Status is: ❌ Not Found
**Certificate hasn't been created yet**

**Action**: Run infrastructure workflow
1. Go to: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-infra.yaml
2. Click "Run workflow"
3. Select Action: `apply`
4. Wait for completion (2-5 minutes)

### If Status is: ⏳ PENDING_VALIDATION
**Certificate is being validated (this is normal)**

**Action**: Wait and check again
- Validation takes 5-30 minutes
- Check again in 10-15 minutes
- Status will change to `ISSUED` when ready

### If Status is: ✅ ISSUED
**Certificate is ready!**

**Action**: Run deployment workflow to enable HTTPS
1. Go to: https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-deploy.yaml
2. Click "Run workflow"
3. Wait for completion (5-10 minutes)
4. HTTPS will be automatically configured

## Next Steps After Certificate is ISSUED

Once certificate status is `ISSUED`:

1. ✅ **Run deployment workflow** (will auto-configure HTTPS)
2. ✅ **Wait 2-5 minutes** for LoadBalancer to reconfigure
3. ✅ **Test HTTPS**: `https://prospectf500-app1-dev.agents.opsera-labs.com/`

## Quick Status Check

**What's the current status?**
- Check the infrastructure workflow output, OR
- Check AWS Console

**Then follow the action above based on the status.**

---

**Last Updated**: 2026-01-09
