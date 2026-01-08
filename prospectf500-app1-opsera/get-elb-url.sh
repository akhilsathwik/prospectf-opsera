#!/bin/bash
# Quick script to get ELB URL

REGION="eu-north-1"
APP_IDENTIFIER="prospectf500-app1"
ENVIRONMENT="dev"
WORKLOAD_CLUSTER="${APP_IDENTIFIER}-wrk-${ENVIRONMENT}"
NAMESPACE="${APP_IDENTIFIER}-${ENVIRONMENT}"

echo "Getting ELB URL for service: ${APP_IDENTIFIER}-frontend"
echo ""

# Configure kubectl
aws eks update-kubeconfig --name $WORKLOAD_CLUSTER --region $REGION

# Get LoadBalancer hostname
LB_HOSTNAME=$(kubectl get svc ${APP_IDENTIFIER}-frontend -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -n "$LB_HOSTNAME" ] && [ "$LB_HOSTNAME" != "" ]; then
    echo "=========================================="
    echo "ELB URL Found!"
    echo "=========================================="
    echo ""
    echo "HTTP:  http://$LB_HOSTNAME"
    echo "HTTPS: https://$LB_HOSTNAME"
    echo ""
    echo "Test with:"
    echo "  curl http://$LB_HOSTNAME"
    echo ""
else
    echo "⚠ LoadBalancer is still pending..."
    echo ""
    echo "Check service status:"
    kubectl get svc ${APP_IDENTIFIER}-frontend -n $NAMESPACE
    echo ""
    echo "If service exists but LoadBalancer is pending, wait 2-5 minutes"
fi
