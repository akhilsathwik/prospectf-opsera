# Fresh Deployment - Configuration

## Your Configuration:

| Input | Value |
|-------|-------|
| Tenant Name | opsera-se |
| Application Name | prospectf500-app1 |
| Environment | dev |
| AWS Region | eu-north-1 |

## Auto-derived Resources:

| Resource | Pattern | Value |
|----------|---------|-------|
| ArgoCD Cluster | argocd-{region} | argocd-eu-north-1 |
| Workload Cluster | {tenant}-{region}-{cluster_env} | opsera-se-eu-north-1-nonprod |
| ECR Repository | {tenant}/{app} | opsera-se/prospectf500-app1 |
| Namespace | {app}-{env} | prospectf500-app1-dev |
| ArgoCD App | {app}-{env} | prospectf500-app1-dev |

**Note**: `cluster_env` = `nonprod` (since environment is `dev`, not `prod`)

Proceeding with infrastructure discovery...
