# LoadBalancer Connection Timeout - Troubleshooting Guide

## Problem
The LoadBalancer URL is generated (`http://a4bfb78700763431d9e5a0d0a49032cf-27bdb1e0e7029526.elb.eu-north-1.amazonaws.com`) but connection times out with `ERR_CONNECTION_TIMED_OUT`.

## Root Cause
**The LoadBalancer exists but has NO HEALTHY TARGETS because pods are not running.**

When pods don't start, the LoadBalancer target group has no healthy targets, so all connections time out.

## Diagnosis Steps

### 1. Check Pod Status
```bash
kubectl get pods -n prospectf500-app1-dev
```

**Expected:** Pods should be in `Running` state
**Actual:** Pods are likely in `Pending`, `ImagePullBackOff`, or `CrashLoopBackOff`

### 2. Check Pod Events
```bash
kubectl describe pod <pod-name> -n prospectf500-app1-dev
```

Look for:
- **ImagePullBackOff**: Cannot pull image from ECR
- **CrashLoopBackOff**: Container starts but crashes immediately
- **Pending**: Resource constraints or scheduling issues

### 3. Check LoadBalancer Target Group Health
```bash
# Get LoadBalancer ARN
LB_ARN=$(aws elbv2 describe-load-balancers --region eu-north-1 \
  --query "LoadBalancers[?contains(DNSName, 'a4bfb78700763431d9e5a0d0a49032cf')].LoadBalancerArn" \
  --output text)

# Get target groups
TG_ARNS=$(aws elbv2 describe-target-groups --load-balancer-arn $LB_ARN \
  --region eu-north-1 --query 'TargetGroups[*].TargetGroupArn' --output text)

# Check target health
for TG_ARN in $TG_ARNS; do
  echo "Target Group: $TG_ARN"
  aws elbv2 describe-target-health --target-group-arn $TG_ARN \
    --region eu-north-1 --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
    --output table
done
```

**Expected:** Targets should be `healthy`
**Actual:** Targets are likely `unhealthy` or `unused` (no targets registered)

## Common Fixes

### Fix 1: ECR Image Pull Permissions
**Symptom:** `ImagePullBackOff` error in pod events

**Solution:** The EKS node group IAM role needs ECR read permissions. The terraform-aws-modules/eks module should handle this automatically, but we've added an explicit policy attachment.

**Verify:**
```bash
# Get node group IAM role
NODE_ROLE=$(aws eks describe-nodegroup \
  --cluster-name prospectf500-app1-wrk-dev \
  --nodegroup-name $(aws eks list-nodegroups --cluster-name prospectf500-app1-wrk-dev --query 'nodegroups[0]' --output text) \
  --region eu-north-1 --query 'nodegroup.nodeRole' --output text | cut -d'/' -f2)

# Check if ECR policy is attached
aws iam list-attached-role-policies --role-name $NODE_ROLE --region eu-north-1 | grep ECR
```

### Fix 2: Verify ECR Images Exist
**Symptom:** Image not found errors

**Solution:** Ensure images were pushed to ECR with correct tags

**Check:**
```bash
aws ecr list-images --repository-name prospectf500-app1-backend --region eu-north-1
aws ecr list-images --repository-name prospectf500-app1-frontend --region eu-north-1
```

### Fix 3: Check Image Names in Deployment
**Symptom:** Wrong image name in deployment

**Solution:** Verify Kustomize correctly replaced image names

**Check:**
```bash
kubectl get deployment prospectf500-app1-backend -n prospectf500-app1-dev -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl get deployment prospectf500-app1-frontend -n prospectf500-app1-dev -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Expected:** Should show full ECR URL like `792373136340.dkr.ecr.eu-north-1.amazonaws.com/prospectf500-app1-backend:latest`

### Fix 4: Security Groups (Usually Not the Issue)
**Note:** When using NLB with `target_type: "ip"`, AWS automatically manages security groups. Manual security group rules are usually not needed.

**If needed, verify:**
```bash
# Get node security group
NODE_SG=$(aws eks describe-cluster --name prospectf500-app1-wrk-dev \
  --region eu-north-1 --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)

# Check ingress rules
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$NODE_SG" \
  --region eu-north-1 --query 'SecurityGroupRules[?IsEgress==`false`]'
```

## Quick Fix Workflow

1. **Re-run deployment workflow** to ensure latest images are deployed
2. **Check GitHub Actions logs** for pod status in "Check pod status and events" step
3. **If ImagePullBackOff**: Verify ECR permissions (Fix 1)
4. **If CrashLoopBackOff**: Check pod logs for application errors
5. **If Pending**: Check node resources and scheduling

## Verification

Once pods are running:
```bash
# Pods should be Running
kubectl get pods -n prospectf500-app1-dev

# LoadBalancer should have healthy targets
# (Check via AWS Console or CLI as shown above)

# Test endpoint
curl http://a4bfb78700763431d9e5a0d0a49032cf-27bdb1e0e7029526.elb.eu-north-1.amazonaws.com
```

## Next Steps

After fixing pod issues:
1. Wait 2-5 minutes for LoadBalancer to register healthy targets
2. Test the ELB URL again
3. Wait for DNS propagation (if using custom domain)

---
**Last Updated:** 2026-01-08
**Status:** Active troubleshooting guide
