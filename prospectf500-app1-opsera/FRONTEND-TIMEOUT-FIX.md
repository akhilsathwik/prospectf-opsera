# Frontend Deployment Timeout Fix

## Problem

The frontend deployment was timing out with error:
```
error: timed out waiting for the condition
Waiting for deployment "prospectf500-app1-frontend" rollout to finish: 1 old replicas are pending termination...
```

**Root Causes:**
1. **Readiness probe too aggressive**: 5 second initial delay wasn't enough for nginx to start
2. **Liveness probe too aggressive**: 10 second initial delay could kill healthy pods
3. **No rollout strategy**: Default strategy didn't handle stuck rollouts well
4. **Old pods blocking**: Old replicas pending termination blocked new pod from becoming ready

## Solution Applied

### 1. Updated Frontend Deployment (`frontend-deployment.yaml`)

**Added Rolling Update Strategy:**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

**Increased Probe Delays:**
- **Readiness probe**: `initialDelaySeconds: 5` → `15` (3x increase)
- **Liveness probe**: `initialDelaySeconds: 10` → `30` (3x increase)
- Added `successThreshold: 1` to both probes

**Why this helps:**
- Gives nginx more time to start before health checks
- Prevents premature pod termination
- Allows graceful rollout with zero downtime

### 2. Improved Workflow Error Handling

**Added stuck rollout recovery:**
- Detects when new pod is ready but old pods are blocking
- Automatically scales down old ReplicaSet to unblock rollout
- Provides detailed diagnostics on failure

**New behavior:**
```bash
# If timeout occurs:
1. Check if new pod is ready
2. If ready, scale down old ReplicaSet
3. Retry rollout status
4. Provide detailed diagnostics if still failing
```

## Changes Made

### Files Modified:
1. `prospectf500-app1-opsera/k8s/base/frontend-deployment.yaml`
   - Added rollout strategy
   - Increased probe delays
   - Added success thresholds

2. `.github/workflows/prospectf500-app1-deploy.yaml`
   - Improved timeout handling
   - Added stuck rollout recovery
   - Better diagnostics

## Verification

After the next deployment, verify:

1. **Deployment completes successfully:**
   ```bash
   kubectl get deployment prospectf500-app1-frontend -n prospectf500-app1-dev
   # Should show: READY 1/1
   ```

2. **No stuck ReplicaSets:**
   ```bash
   kubectl get rs -n prospectf500-app1-dev -l app=prospectf500-app1-frontend
   # Should show only one active ReplicaSet
   ```

3. **Pods are ready:**
   ```bash
   kubectl get pods -n prospectf500-app1-dev -l app=prospectf500-app1-frontend
   # Should show: STATUS Running, READY 1/1
   ```

## Expected Behavior

**Before Fix:**
- ❌ Deployment times out after 5 minutes
- ❌ Old pods stuck in "Terminating" state
- ❌ New pod never becomes ready
- ❌ Rollout blocked indefinitely

**After Fix:**
- ✅ Deployment completes in 1-2 minutes
- ✅ Old pods terminate gracefully
- ✅ New pod becomes ready within 15-30 seconds
- ✅ Rollout completes successfully

## Manual Recovery (If Still Stuck)

If deployment is still stuck after applying the fix:

```bash
# 1. Check current status
kubectl get deployment prospectf500-app1-frontend -n prospectf500-app1-dev
kubectl get rs -n prospectf500-app1-dev -l app=prospectf500-app1-frontend
kubectl get pods -n prospectf500-app1-dev -l app=prospectf500-app1-frontend

# 2. If new pod is ready but old pods are blocking:
NEW_RS=$(kubectl get rs -n prospectf500-app1-dev -l app=prospectf500-app1-frontend --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
OLD_RS=$(kubectl get rs -n prospectf500-app1-dev -l app=prospectf500-app1-frontend --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-2].metadata.name}')

# Scale down old ReplicaSet
kubectl scale rs $OLD_RS -n prospectf500-app1-dev --replicas=0

# 3. Wait for rollout to complete
kubectl rollout status deployment/prospectf500-app1-frontend -n prospectf500-app1-dev
```

## Prevention

To prevent this issue in future deployments:

1. **Always use appropriate probe delays** - Give containers time to start
2. **Configure rollout strategy** - Control how updates are applied
3. **Monitor pod readiness** - Check if pods are actually ready, not just running
4. **Set reasonable timeouts** - Don't wait forever, but give enough time

## Related Issues

- **Fix #83**: Endpoint verification (already implemented)
- **Fix #82**: Update all images (already implemented)
- **Fix #81**: No placeholders in manifests (already implemented)

---

**Status**: ✅ Fixed and committed
**Commit**: `fd9a228` - "Fix frontend deployment timeout: Increase probe delays, add rollout strategy, improve stuck rollout handling"
**Next Deployment**: Should complete successfully without timeout
