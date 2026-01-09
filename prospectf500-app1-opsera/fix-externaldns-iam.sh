#!/bin/bash
# Quick fix script for ExternalDNS IAM role trust policy
# This updates the existing IAM role with the correct OIDC issuer URL format

set -e

CLUSTER_NAME="prospectf500-app1-wrk-dev"
REGION="eu-north-1"
ROLE_NAME="prospectf500-app1-external-dns"

echo "========================================"
echo "  Fix ExternalDNS IAM Role Trust Policy"
echo "========================================"
echo ""

# Get OIDC issuer URL from cluster
echo "Getting OIDC issuer URL from cluster..."
ISSUER_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION \
  --query 'cluster.identity.oidc.issuer' --output text)

if [ -z "$ISSUER_URL" ]; then
  echo "❌ ERROR: Could not get OIDC issuer URL"
  exit 1
fi

echo "✓ OIDC Issuer URL: $ISSUER_URL"

# Remove https:// prefix for condition key
ISSUER_HOST=$(echo $ISSUER_URL | sed 's|https://||')
echo "✓ OIDC Issuer Host: $ISSUER_HOST"

# Get OIDC provider ARN
echo ""
echo "Getting OIDC provider ARN..."
OIDC_PROVIDER_ARN=$(aws iam list-open-id-connect-providers --query \
  "OpenIDConnectProviderList[?contains(Arn, '$(echo $ISSUER_HOST | cut -d'/' -f1)')].Arn" \
  --output text | head -1)

if [ -z "$OIDC_PROVIDER_ARN" ]; then
  echo "⚠ WARNING: Could not find OIDC provider ARN automatically"
  echo "You may need to create the OIDC provider first"
  echo "Run: aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.identity.oidc.issuer'"
  exit 1
fi

echo "✓ OIDC Provider ARN: $OIDC_PROVIDER_ARN"

# Create trust policy JSON
echo ""
echo "Creating updated trust policy..."
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_PROVIDER_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "$ISSUER_HOST:sub": "system:serviceaccount:kube-system:external-dns",
          "$ISSUER_HOST:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF
)

echo "$TRUST_POLICY" > /tmp/trust-policy.json
echo "✓ Trust policy created"

# Update IAM role
echo ""
echo "Updating IAM role: $ROLE_NAME..."
aws iam update-assume-role-policy \
  --role-name $ROLE_NAME \
  --policy-document file:///tmp/trust-policy.json

if [ $? -eq 0 ]; then
  echo "✓ IAM role trust policy updated successfully!"
else
  echo "❌ ERROR: Failed to update IAM role"
  exit 1
fi

# Clean up
rm -f /tmp/trust-policy.json

echo ""
echo "========================================"
echo "  Next Steps"
echo "========================================"
echo ""
echo "1. Restart ExternalDNS pod:"
echo "   kubectl delete pod -n kube-system -l app=external-dns"
echo ""
echo "2. Check ExternalDNS status:"
echo "   kubectl get pods -n kube-system -l app=external-dns"
echo ""
echo "3. Check ExternalDNS logs:"
echo "   kubectl logs -n kube-system -l app=external-dns --tail=20"
echo ""
echo "4. Wait for DNS record creation (1-2 minutes)"
echo ""
