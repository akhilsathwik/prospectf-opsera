# DNS Record Troubleshooting Guide

## ✅ Current Status

**LoadBalancer**: ✅ **WORKING**
- URL: `http://a4bfb78700763431d9e5a0d0a49032cf-27bdb1e0e7029526.elb.eu-north-1.amazonaws.com/`
- Status: Application is accessible!

**DNS Record**: ⚠️ **NOT CREATED YET**
- Domain: `prospectf500-app1-dev.agents.opsera-labs.com`
- Hosted Zone: `Z00814191D1XSXELJVTKT` (opsera-labs.com)
- Status: ExternalDNS hasn't created the record yet

## 🔍 Why DNS Record Not Created?

ExternalDNS creates DNS records when:
1. ✅ Service exists with `type: LoadBalancer`
2. ✅ Service has ExternalDNS annotation: `external-dns.alpha.kubernetes.io/hostname`
3. ✅ LoadBalancer has endpoint (ready)
4. ⚠️ ExternalDNS pod is running
5. ⚠️ ExternalDNS has Route53 permissions
6. ⚠️ ExternalDNS has detected the service

## 🔧 Troubleshooting Steps

### Step 1: Check ExternalDNS Pod Status

**Via GitHub Actions:**
1. Go to: `Check DNS and ExternalDNS Status` job
2. Find: `Check ExternalDNS Status` step
3. Check if pod is `Running`

**Expected output:**
```
NAME                          READY   STATUS    RESTARTS   AGE
external-dns-xxxxx-xxxxx      1/1     Running   0          10m
```

**If not running:**
- ExternalDNS might not be installed
- Run infrastructure workflow with `action=apply` to install it

### Step 2: Check ExternalDNS Logs

**Via GitHub Actions:**
1. In `Check ExternalDNS Status` step
2. Look for logs showing:
   - ✅ "Creating DNS record"
   - ✅ "Successfully created"
   - ❌ Permission errors
   - ❌ "hosted zone not found"

**Common log messages:**
```
time="..." level=info msg="Creating DNS record: prospectf500-app1-dev.agents.opsera-labs.com"
time="..." level=info msg="Successfully created DNS record"
```

**If you see errors:**
- Permission errors → Check IAM role permissions
- "hosted zone not found" → Verify hosted zone exists
- "no suitable service" → Check service annotation

### Step 3: Verify Service Annotation

The service should have this annotation:
```yaml
annotations:
  external-dns.alpha.kubernetes.io/hostname: prospectf500-app1-dev.agents.opsera-labs.com
```

**Check via GitHub Actions:**
1. Go to: `Deploy to Workload Cluster` job
2. Find: `Deploy with Kustomize` step
3. Look for service being applied

### Step 4: Check ExternalDNS Configuration

ExternalDNS should be configured with:
- `--domain-filter=opsera-labs.com` ✅
- `--provider=aws` ✅
- `--source=service` ✅

**Check if ExternalDNS is installed:**
- Infrastructure workflow should have installed it
- If not, run infrastructure workflow with `action=apply`

### Step 5: Manual DNS Record Creation (If Needed)

If ExternalDNS isn't working, you can manually create the DNS record:

```bash
# Get LoadBalancer hostname
LB_HOSTNAME="a4bfb78700763431d9e5a0d0a49032cf-27bdb1e0e7029526.elb.eu-north-1.amazonaws.com"

# Get hosted zone ID
HOSTED_ZONE_ID="Z00814191D1XSXELJVTKT"

# Create DNS record
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "prospectf500-app1-dev.agents.opsera-labs.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'$LB_HOSTNAME'"}]
      }
    }]
  }'
```

## ⏱️ Expected Timeline

| Step | Duration | Status |
|------|----------|--------|
| LoadBalancer provisioned | 2-5 min | ✅ Done |
| ExternalDNS detects service | 1-2 min | ⏳ In progress |
| ExternalDNS creates DNS record | 1-2 min | ⏳ Waiting |
| DNS propagation | 5-10 min | ⏳ Waiting |
| **Total** | **10-20 min** | |

## 🎯 Immediate Access

**You can access your application RIGHT NOW using:**

```
http://a4bfb78700763431d9e5a0d0a49032cf-27bdb1e0e7029526.elb.eu-north-1.amazonaws.com/
```

**This works immediately** - you don't need to wait for DNS!

## 📋 Checklist

- [x] LoadBalancer is working
- [x] Application is accessible via LoadBalancer URL
- [ ] ExternalDNS pod is running
- [ ] ExternalDNS has created DNS record
- [ ] DNS record has propagated
- [ ] DNS endpoint is accessible

## 🔄 Next Steps

1. **Wait 5-10 minutes** - ExternalDNS usually creates records within this time
2. **Check ExternalDNS logs** - Via GitHub Actions to see what's happening
3. **If still not created after 10 minutes:**
   - Check ExternalDNS pod status
   - Check ExternalDNS logs for errors
   - Verify IAM permissions
   - Consider manual DNS record creation

## 🐛 Common Issues

### Issue 1: ExternalDNS Not Installed
**Symptom**: No ExternalDNS pod found

**Fix**: Run infrastructure workflow with `action=apply` to install ExternalDNS

### Issue 2: ExternalDNS Permission Errors
**Symptom**: Logs show "AccessDenied" or "Forbidden"

**Fix**: Verify IAM role has Route53 permissions:
```bash
aws iam get-role-policy \
  --role-name prospectf500-app1-external-dns \
  --policy-name prospectf500-app1-external-dns-policy
```

### Issue 3: ExternalDNS Not Detecting Service
**Symptom**: No logs about creating DNS record

**Fix**: 
- Verify service annotation is correct
- Restart ExternalDNS pod: `kubectl delete pod -n kube-system -l app=external-dns`
- Check ExternalDNS logs after restart

### Issue 4: DNS Record Created But Not Resolving
**Symptom**: Record exists in Route53 but doesn't resolve

**Fix**: Wait 5-10 minutes for DNS propagation (this is normal)

---

**Status**: ✅ Deployment successful! Application is accessible via LoadBalancer URL.
**DNS**: ⏳ Waiting for ExternalDNS to create record (normal, takes 5-10 minutes)
