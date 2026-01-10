# Kubernetes Namespace Information

## Namespace Name

**`prospectf500-app1-dev`**

## Namespace Details

### Full Namespace Information

| Property | Value |
|----------|-------|
| **Namespace Name** | `prospectf500-app1-dev` |
| **Format** | `{app-identifier}-{environment}` |
| **App Identifier** | `prospectf500-app1` |
| **Environment** | `dev` |
| **Tenant** | `opsera-se` |

### Namespace Structure

```
prospectf500-app1-dev
│
├─ prospectf500-app1 = Application identifier
└─ dev = Environment (development)
```

## Where It's Used

### 1. Kubernetes Manifests

**File**: `k8s/base/namespace.yaml`
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: prospectf500-app1-dev
  labels:
    app-identifier: prospectf500-app1
    environment: dev
    tenant: opsera-se
```

**File**: `k8s/base/kustomization.yaml`
```yaml
namespace: prospectf500-app1-dev
```

### 2. GitHub Actions Workflows

All `kubectl` commands in the workflows use:
```bash
-n prospectf500-app1-dev
# or
-n ${{ env.APP_IDENTIFIER }}-${{ env.ENVIRONMENT }}
# which resolves to: prospectf500-app1-dev
```

### 3. Resources Deployed in This Namespace

- ✅ **Namespace**: `prospectf500-app1-dev` (the namespace itself)
- ✅ **Backend Deployment**: `prospectf500-app1-backend`
- ✅ **Frontend Deployment**: `prospectf500-app1-frontend`
- ✅ **Backend Service**: `prospectf500-app1-backend` (ClusterIP)
- ✅ **Frontend Service**: `prospectf500-app1-frontend` (LoadBalancer)
- ✅ **Secrets**: `openai-api-key` (when created)

## Common Commands Using This Namespace

### View All Resources
```bash
kubectl get all -n prospectf500-app1-dev
```

### View Pods
```bash
kubectl get pods -n prospectf500-app1-dev
```

### View Services
```bash
kubectl get svc -n prospectf500-app1-dev
```

### View Deployments
```bash
kubectl get deployments -n prospectf500-app1-dev
```

### View Namespace Details
```bash
kubectl describe namespace prospectf500-app1-dev
```

### Create Secret (OpenAI API Key)
```bash
kubectl create secret generic openai-api-key \
  --from-literal=OPENAI_API_KEY=your-key-here \
  -n prospectf500-app1-dev
```

### View Logs
```bash
# Backend logs
kubectl logs -l app=prospectf500-app1-backend -n prospectf500-app1-dev

# Frontend logs
kubectl logs -l app=prospectf500-app1-frontend -n prospectf500-app1-dev
```

### Restart Deployment
```bash
kubectl rollout restart deployment prospectf500-app1-backend -n prospectf500-app1-dev
kubectl rollout restart deployment prospectf500-app1-frontend -n prospectf500-app1-dev
```

### Delete Namespace (⚠️ Destroys All Resources)
```bash
kubectl delete namespace prospectf500-app1-dev
```

## Namespace Labels

The namespace has the following labels for organization and filtering:

| Label | Value | Purpose |
|-------|-------|---------|
| `app-identifier` | `prospectf500-app1` | Identifies the application |
| `environment` | `dev` | Identifies the environment |
| `tenant` | `opsera-se` | Identifies the tenant |
| `managed-by` | `opsera-gitops` | Indicates GitOps management |
| `created-by` | `claude-code` | Creation metadata |

## Other Namespaces in the Cluster

While your application runs in `prospectf500-app1-dev`, the cluster also has:

- **`kube-system`**: System components (ExternalDNS, etc.)
- **`argocd`**: ArgoCD GitOps controller
- **`default`**: Default namespace (usually empty)

## Summary

**Your Kubernetes namespace is**: `prospectf500-app1-dev`

This namespace:
- ✅ Contains all your application resources
- ✅ Is isolated from other applications
- ✅ Is managed by GitOps (ArgoCD)
- ✅ Follows naming convention: `{app}-{env}`

**Quick Reference**:
- Always use `-n prospectf500-app1-dev` with `kubectl` commands
- All your deployments, services, and pods are in this namespace
- Secrets should also be created in this namespace

---

**Last Updated**: 2026-01-09  
**Status**: Active namespace for your application
