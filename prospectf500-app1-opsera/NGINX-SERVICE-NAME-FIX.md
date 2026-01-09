# Nginx Service Name Fix - Root Cause Analysis

## Problem

The frontend pod was crashing with error:
```
nginx: [emerg] host not found in upstream "your-username-backend" in /etc/nginx/conf.d/default.conf:20
```

**Root Cause**: The `frontend/nginx.conf` file was incorrectly updated to use `your-username-backend` instead of `prospectf500-app1-backend`.

## Why This Happened

1. **Shared Frontend Code**: The `frontend/nginx.conf` file is shared across multiple deployments
2. **Incorrect Update**: When setting up the `your-username` deployment, the nginx.conf was changed to use `your-username-backend`
3. **Impact**: This broke the `prospectf500-app1` deployment because it needs `prospectf500-app1-backend`

## The Error Chain

```
1. nginx.conf changed: prospectf500-app1-backend → your-username-backend
2. Frontend image built with wrong service name
3. Pod starts, nginx tries to resolve "your-username-backend"
4. Service doesn't exist in prospectf500-app1-dev namespace
5. nginx fails to start → CrashLoopBackOff
6. Deployment times out waiting for pod to become ready
```

## Fix Applied

**Reverted nginx.conf to use correct service name:**
```nginx
proxy_pass http://prospectf500-app1-backend:8000/api;
```

**Also fixed workflow script error:**
- Fixed integer comparison when checking ReplicaSet ready status
- Added proper handling for empty values

## Prevention

### Short-term Solution (Current)
- **Hardcoded service name** in nginx.conf for each deployment
- Works but requires manual updates for each deployment

### Long-term Solution (Recommended)
Make nginx.conf configurable via environment variable:

1. **Update Dockerfile** to use envsubst:
```dockerfile
# In frontend/Dockerfile
RUN apk add --no-cache gettext
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
ENV BACKEND_SERVICE_NAME=prospectf500-app1-backend
```

2. **Update nginx.conf** to use template variable:
```nginx
proxy_pass http://${BACKEND_SERVICE_NAME}:8000/api;
```

3. **Update deployment** to set environment variable:
```yaml
env:
  - name: BACKEND_SERVICE_NAME
    value: "prospectf500-app1-backend"
```

4. **Update Dockerfile CMD** to run envsubst:
```dockerfile
CMD ["/bin/sh", "-c", "envsubst '$$BACKEND_SERVICE_NAME' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
```

### Alternative: Deployment-Specific ConfigMaps

Create a ConfigMap per deployment with the correct nginx.conf:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-nginx-config
data:
  nginx.conf: |
    # ... nginx config with correct service name ...
```

Then mount it in the deployment:
```yaml
volumeMounts:
  - name: nginx-config
    mountPath: /etc/nginx/conf.d/default.conf
    subPath: nginx.conf
volumes:
  - name: nginx-config
    configMap:
      name: frontend-nginx-config
```

## Files Changed

1. ✅ `frontend/nginx.conf` - Reverted to `prospectf500-app1-backend`
2. ✅ `.github/workflows/prospectf500-app1-deploy.yaml` - Fixed integer comparison

## Commits

- `407ae22` - Fix nginx.conf: Revert to prospectf500-app1-backend service name
- `17b94f2` - Fix workflow: Handle empty values in integer comparison

## Next Steps

1. ✅ **Immediate**: Fix is applied and committed
2. 🔄 **Future**: Implement environment variable-based configuration
3. 🔄 **Future**: Create deployment-specific nginx configs for each app

## Lesson Learned

**Never hardcode deployment-specific values in shared files!**

- Use environment variables
- Use ConfigMaps
- Use deployment-specific overlays
- Always verify changes don't break other deployments

---

**Status**: ✅ Fixed
**Impact**: Frontend deployment should now succeed
**Next Deployment**: Will use correct service name
