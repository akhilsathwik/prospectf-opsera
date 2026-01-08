# DNS Endpoint Troubleshooting Guide

**Issue:** `https://prospectf500-app1-dev.agents.opsera-labs.com` returns DNS_PROBE_FINISHED_NXDOMAIN

---

## Why DNS Record Might Not Exist

The DNS record is created by **ExternalDNS** when:
1. ✅ Service with `type: LoadBalancer` exists
2. ✅ Service has ExternalDNS annotation: `external-dns.alpha.kubernetes.io/hostname`
3. ✅ LoadBalancer has been provisioned (has an endpoint)
4. ✅ ExternalDNS pod is running and has Route53 permissions
5. ✅ Route53 hosted zone `opsera-labs.com` exists

---

## Quick Checks

### 1. Check if Service and LoadBalancer Exist

```bash
# Connect to workload cluster
aws eks update-kubeconfig --name prospectf500-app1-wrk-dev --region eu-north-1

# Check service
kubectl get svc prospectf500-app1-frontend -n prospectf500-app1-dev

# Check LoadBalancer endpoint
kubectl get svc prospectf500-app1-frontend -n prospectf500-app1-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**Expected:** Should show a LoadBalancer hostname (e.g., `xxxxx-xxxxx.elb.eu-north-1.amazonaws.com`)

**If pending:** Wait 2-5 minutes for AWS to provision the LoadBalancer

---

### 2. Check ExternalDNS Pod

```bash
# Check if ExternalDNS is running
kubectl get pods -n kube-system -l app=external-dns

# Check ExternalDNS logs
kubectl logs -n kube-system -l app=external-dns --tail=50
```

**Look for:**
- ✅ "Creating DNS record" messages
- ✅ "Successfully created" messages
- ❌ Permission errors
- ❌ "hosted zone not found" errors

---

### 3. Check Route53 DNS Record

```bash
# List hosted zones
aws route53 list-hosted-zones --query 'HostedZones[*].Name' --output table

# Check if record exists (replace ZONE_ID with actual hosted zone ID)
aws route53 list-resource-record-sets \
  --hosted-zone-id ZONE_ID \
  --query "ResourceRecordSets[?Name=='prospectf500-app1-dev.agents.opsera-labs.com.']"
```

**Expected:** Should show an A record pointing to the LoadBalancer

---

### 4. Check ExternalDNS Permissions

```bash
# Check ServiceAccount annotation
kubectl get serviceaccount external-dns -n kube-system -o yaml | grep eks.amazonaws.com/role-arn

# Verify IAM role exists
aws iam get-role --role-name prospectf500-app1-external-dns
```

**Expected:** Should show IAM role ARN with Route53 permissions

---

## Common Issues and Fixes

### Issue 1: LoadBalancer Still Pending

**Symptom:** `kubectl get svc` shows `<pending>` for LoadBalancer

**Fix:** Wait 2-5 minutes. AWS needs time to provision the LoadBalancer.

**Check:**
```bash
kubectl describe svc prospectf500-app1-frontend -n prospectf500-app1-dev
```

---

### Issue 2: ExternalDNS Not Running

**Symptom:** No ExternalDNS pod found

**Fix:** Re-run infrastructure workflow with `action=apply` to install ExternalDNS

---

### Issue 3: ExternalDNS Permission Errors

**Symptom:** Logs show "AccessDenied" or "Forbidden"

**Fix:** Verify IAM role has Route53 permissions:
```bash
aws iam get-role-policy \
  --role-name prospectf500-app1-external-dns \
  --policy-name prospectf500-app1-external-dns-policy
```

---

### Issue 4: Route53 Hosted Zone Not Found

**Symptom:** ExternalDNS logs show "hosted zone not found"

**Fix:** 
1. Verify hosted zone `opsera-labs.com` exists in Route53
2. If it doesn't exist, create it or update ExternalDNS domain filter

---

### Issue 5: DNS Propagation Delay

**Symptom:** DNS record exists in Route53 but browser can't resolve

**Fix:** Wait 5-10 minutes for DNS propagation. This is normal.

**Check DNS propagation:**
```bash
dig prospectf500-app1-dev.agents.opsera-labs.com
# or
nslookup prospectf500-app1-dev.agents.opsera-labs.com
```

---

## Manual DNS Record Creation (If Needed)

If ExternalDNS isn't working, you can manually create the DNS record:

```bash
# Get LoadBalancer hostname
LB_HOSTNAME=$(kubectl get svc prospectf500-app1-frontend -n prospectf500-app1-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Get LoadBalancer IP (if NLB)
LB_IP=$(dig +short $LB_HOSTNAME | head -1)

# Get hosted zone ID
ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='opsera-labs.com.'].[Id]" --output text | sed 's|/hostedzone/||')

# Create DNS record
aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "prospectf500-app1-dev.agents.opsera-labs.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'$LB_IP'"}]
      }
    }]
  }'
```

---

## Expected Timeline

1. **Service created:** Immediate
2. **LoadBalancer provisioned:** 2-5 minutes
3. **ExternalDNS creates DNS record:** 1-2 minutes after LoadBalancer ready
4. **DNS propagation:** 5-10 minutes
5. **Total:** 8-17 minutes from service creation

---

## Verification

Once DNS is working, verify:

```bash
# Check DNS resolution
curl -I https://prospectf500-app1-dev.agents.opsera-labs.com

# Or in browser
# https://prospectf500-app1-dev.agents.opsera-labs.com
```

**Expected:** Should return HTTP 200 or show the application

---

## Next Steps

1. Check the deployment workflow's "Check DNS" job output
2. Review ExternalDNS logs
3. Verify LoadBalancer is ready
4. Wait for DNS propagation (5-10 minutes)
5. Try accessing the endpoint again

If issues persist, check the GitHub Actions workflow logs for detailed diagnostics.
