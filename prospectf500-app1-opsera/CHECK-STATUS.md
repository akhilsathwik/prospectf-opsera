# How to Check Deployment Status

Since AWS CLI and kubectl are not installed locally, here are the best ways to check your deployment status:

## ✅ Option 1: Check GitHub Actions (Easiest - No Installation Required)

### Step 1: Check LoadBalancer Status
1. Go to: **https://github.com/akhilsathwik/prospectf-opsera/actions**
2. Open the **latest "prospectf500-app1 Deploy"** workflow run
3. Find the **"Get deployment status"** step
4. Look for output like:
   ```
   ✓ LoadBalancer ready!
   ELB URL: http://xxxxx-xxxxx.elb.eu-north-1.amazonaws.com
   ```

### Step 2: Check DNS Status
1. In the same workflow run, find the **"Check DNS and ExternalDNS Status"** job
2. Check the **"Check Route53 DNS Record"** step
3. It will show:
   - ✅ DNS record EXISTS (if created)
   - ⚠️ DNS record NOT found (if still pending)

### Step 3: Check ExternalDNS
1. In the **"Check DNS and ExternalDNS Status"** job
2. Find the **"Check ExternalDNS Status"** step
3. It shows:
   - ExternalDNS pod status
   - ExternalDNS logs (last 50 lines)

### Step 4: Check Pod Status
1. In the **"Deploy to Workload Cluster"** job
2. Find the **"Check pod status and events"** step
3. It shows:
   - All pods status
   - Recent events
   - Pod logs if there are issues

---

## ✅ Option 2: Use AWS Console (No CLI Required)

### Check LoadBalancer
1. Go to: **https://console.aws.amazon.com/ec2/**
2. Click: **Load Balancers** (left sidebar)
3. Find: Load balancer with name containing `prospectf500-app1-frontend`
4. Copy the **DNS name** (e.g., `xxxxx-xxxxx.elb.eu-north-1.amazonaws.com`)

### Check Route53 DNS Record
1. Go to: **https://console.aws.amazon.com/route53/**
2. Click: **Hosted zones**
3. Select: **opsera-labs.com**
4. Look for: **prospectf500-app1-dev.agents.opsera-labs.com** record
5. If it exists, it will show the LoadBalancer DNS name

### Check EKS Cluster
1. Go to: **https://console.aws.amazon.com/eks/**
2. Select: **prospectf500-app1-wrk-dev** cluster
3. Click: **Resources** tab
4. Check: **Services** to see the frontend service

---

## ✅ Option 3: Install Tools and Run Commands

### Install Required Tools

**Install AWS CLI:**
```powershell
# Using winget (Windows 11/10)
winget install Amazon.AWSCLI

# Or download installer from:
# https://aws.amazon.com/cli/
```

**Install kubectl:**
```powershell
# Using winget
winget install Kubernetes.kubectl

# Or download from:
# https://kubernetes.io/docs/tasks/tools/
```

**Install dig (for DNS queries):**
```powershell
# Using Chocolatey
choco install bind-toolsonly

# Or use PowerShell's Resolve-DnsName instead
```

### Configure AWS Credentials
```powershell
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter region: eu-north-1
# Enter output format: json
```

### Run the Commands

Once tools are installed, run:

```powershell
# 1. Configure kubectl
aws eks update-kubeconfig --name prospectf500-app1-wrk-dev --region eu-north-1

# 2. Check LoadBalancer
kubectl get svc prospectf500-app1-frontend -n prospectf500-app1-dev

# 3. Get LoadBalancer URL
kubectl get svc prospectf500-app1-frontend -n prospectf500-app1-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# 4. Check DNS (PowerShell)
Resolve-DnsName -Name prospectf500-app1-dev.agents.opsera-labs.com

# 5. Check ExternalDNS
kubectl get pods -n kube-system -l app=external-dns
kubectl logs -n kube-system -l app=external-dns --tail=20

# 6. Check Route53
aws route53 list-hosted-zones --query 'HostedZones[*].Name' --output table
```

---

## ✅ Option 4: Use the PowerShell Script

I've created a script that does all of this automatically:

```powershell
.\prospectf500-app1-opsera\get-loadbalancer-url.ps1
```

**Note**: Requires AWS CLI and kubectl to be installed first.

---

## 📊 Quick Status Check (Using PowerShell Built-in)

You can check DNS resolution using PowerShell without installing dig:

```powershell
# Check if DNS resolves
Resolve-DnsName -Name prospectf500-app1-dev.agents.opsera-labs.com

# If it resolves, you'll see the IP address
# If it doesn't, you'll get an error
```

---

## 🔍 What to Look For

### ✅ Healthy Deployment
- **LoadBalancer**: Has a DNS name (not `<pending>`)
- **Pods**: Status is `Running` (not `CrashLoopBackOff` or `Pending`)
- **DNS**: Resolves to an IP address
- **ExternalDNS**: Pod is `Running` and logs show "Successfully created"

### ⚠️ Issues to Watch For
- **LoadBalancer pending**: Wait 2-5 minutes
- **DNS not resolving**: ExternalDNS may not have created the record yet (check logs)
- **Pods not running**: Check pod logs for errors
- **ExternalDNS errors**: Check IAM permissions and Route53 hosted zone

---

## 🚀 Recommended Approach

**For immediate access:**
1. Use **Option 1** (GitHub Actions) to get the LoadBalancer URL
2. Access your app at: `http://<loadbalancer-hostname>`

**For detailed diagnostics:**
1. Use **Option 2** (AWS Console) to check all resources
2. Or install tools (**Option 3**) for command-line access

---

## 📝 Quick Reference

| Resource | How to Check |
|----------|-------------|
| LoadBalancer URL | GitHub Actions → "Get deployment status" step |
| DNS Status | GitHub Actions → "Check DNS and ExternalDNS Status" job |
| Pod Status | GitHub Actions → "Check pod status and events" step |
| ExternalDNS | GitHub Actions → "Check ExternalDNS Status" step |
| Route53 Record | AWS Console → Route53 → Hosted zones → opsera-labs.com |

---

**Current Status**: Check the latest GitHub Actions workflow run for real-time status!
