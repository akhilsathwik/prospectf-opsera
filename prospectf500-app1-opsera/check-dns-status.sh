#!/bin/bash
# DNS and Endpoint Status Check Script

set -e

REGION="eu-north-1"
APP_IDENTIFIER="prospectf500-app1"
ENVIRONMENT="dev"
WORKLOAD_CLUSTER="${APP_IDENTIFIER}-wrk-${ENVIRONMENT}"
NAMESPACE="${APP_IDENTIFIER}-${ENVIRONMENT}"
DOMAIN="prospectf500-app1-dev.agents.opsera-labs.com"
HOSTED_ZONE="opsera-labs.com"

echo "=========================================="
echo "DNS and Endpoint Status Check"
echo "=========================================="
echo "Domain: $DOMAIN"
echo "Namespace: $NAMESPACE"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Step 1: Check Service and LoadBalancer ==="
aws eks update-kubeconfig --name $WORKLOAD_CLUSTER --region $REGION

echo ""
echo "Checking frontend service..."
SERVICE_STATUS=$(kubectl get svc ${APP_IDENTIFIER}-frontend -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "NOT_FOUND")

if [ "$SERVICE_STATUS" = "NOT_FOUND" ]; then
    echo -e "${RED}✗${NC} Service not found or LoadBalancer not created"
    echo "Service details:"
    kubectl get svc ${APP_IDENTIFIER}-frontend -n $NAMESPACE || echo "Service doesn't exist"
else
    echo -e "${GREEN}✓${NC} LoadBalancer created: $SERVICE_STATUS"
fi

echo ""
echo "=== Step 2: Check ExternalDNS Pod ==="
EXTERNALDNS_POD=$(kubectl get pods -n kube-system -l app=external-dns -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$EXTERNALDNS_POD" ]; then
    echo -e "${RED}✗${NC} ExternalDNS pod not found"
else
    echo -e "${GREEN}✓${NC} ExternalDNS pod: $EXTERNALDNS_POD"
    echo ""
    echo "ExternalDNS logs (last 30 lines):"
    kubectl logs $EXTERNALDNS_POD -n kube-system --tail=30 || echo "Could not get logs"
fi

echo ""
echo "=== Step 3: Check Route53 DNS Record ==="
echo "Checking for DNS record: $DOMAIN"

# Get hosted zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${HOSTED_ZONE}.'].[Id]" --output text 2>/dev/null | sed 's|/hostedzone/||' || echo "")

if [ -z "$HOSTED_ZONE_ID" ]; then
    echo -e "${RED}✗${NC} Route53 hosted zone '${HOSTED_ZONE}' not found"
    echo "Available hosted zones:"
    aws route53 list-hosted-zones --query 'HostedZones[*].Name' --output table || echo "Could not list hosted zones"
else
    echo -e "${GREEN}✓${NC} Hosted zone found: $HOSTED_ZONE_ID"
    
    # Check for DNS record
    DNS_RECORD=$(aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --query "ResourceRecordSets[?Name=='${DOMAIN}.']" --output json 2>/dev/null || echo "[]")
    
    if echo "$DNS_RECORD" | grep -q "$DOMAIN"; then
        echo -e "${GREEN}✓${NC} DNS record exists for $DOMAIN"
        echo "DNS record details:"
        aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --query "ResourceRecordSets[?Name=='${DOMAIN}.']" --output table
    else
        echo -e "${RED}✗${NC} DNS record NOT found for $DOMAIN"
        echo ""
        echo "This means ExternalDNS hasn't created the record yet."
        echo "Possible reasons:"
        echo "  1. ExternalDNS pod is not running"
        echo "  2. ExternalDNS doesn't have Route53 permissions"
        echo "  3. Service LoadBalancer is still pending"
        echo "  4. ExternalDNS hasn't processed the service yet"
    fi
fi

echo ""
echo "=== Step 4: Check Pod Status ==="
echo "Frontend pods:"
kubectl get pods -n $NAMESPACE -l app=${APP_IDENTIFIER}-frontend

echo ""
echo "Backend pods:"
kubectl get pods -n $NAMESPACE -l app=${APP_IDENTIFIER}-backend

echo ""
echo "=== Step 5: Check ExternalDNS Permissions ==="
EXTERNALDNS_ROLE=$(kubectl get serviceaccount external-dns -n kube-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || echo "")

if [ -z "$EXTERNALDNS_ROLE" ]; then
    echo -e "${RED}✗${NC} ExternalDNS ServiceAccount doesn't have IRSA annotation"
else
    echo -e "${GREEN}✓${NC} ExternalDNS IAM Role: $EXTERNALDNS_ROLE"
    
    # Check if role has Route53 permissions
    echo ""
    echo "Checking IAM role permissions..."
    aws iam get-role --role-name ${APP_IDENTIFIER}-external-dns --query 'Role.RoleName' --output text 2>/dev/null && \
        echo -e "${GREEN}✓${NC} IAM role exists" || \
        echo -e "${RED}✗${NC} IAM role not found"
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "If DNS record is missing, check:"
echo "  1. ExternalDNS pod logs (see above)"
echo "  2. Service LoadBalancer status"
echo "  3. ExternalDNS IAM permissions"
echo "  4. Route53 hosted zone exists"
echo ""
echo "To manually trigger ExternalDNS sync:"
echo "  kubectl delete pod $EXTERNALDNS_POD -n kube-system"
