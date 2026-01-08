#!/bin/bash
# Infrastructure Verification Script
# This script verifies all infrastructure components are created and ready

set -e

REGION="eu-north-1"
APP_IDENTIFIER="prospectf500-app1"
ENVIRONMENT="dev"
ARGOCD_CLUSTER="${APP_IDENTIFIER}-cd"
WORKLOAD_CLUSTER="${APP_IDENTIFIER}-wrk-${ENVIRONMENT}"

echo "=========================================="
echo "Infrastructure Verification Script"
echo "=========================================="
echo "Region: $REGION"
echo "App Identifier: $APP_IDENTIFIER"
echo "Environment: $ENVIRONMENT"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $1"
        ((FAILED++))
        return 1
    fi
}

echo "=== Phase 1: AWS Resources ==="
echo ""

# Check EKS Clusters
echo "Checking EKS clusters..."
CLUSTERS=$(aws eks list-clusters --region $REGION --query "clusters[?contains(@, '${APP_IDENTIFIER}')]" --output text 2>/dev/null || echo "")

if echo "$CLUSTERS" | grep -q "$ARGOCD_CLUSTER"; then
    check_status "ArgoCD cluster exists: $ARGOCD_CLUSTER"
else
    echo -e "${RED}✗${NC} ArgoCD cluster not found: $ARGOCD_CLUSTER"
    ((FAILED++))
fi

if echo "$CLUSTERS" | grep -q "$WORKLOAD_CLUSTER"; then
    check_status "Workload cluster exists: $WORKLOAD_CLUSTER"
else
    echo -e "${RED}✗${NC} Workload cluster not found: $WORKLOAD_CLUSTER"
    ((FAILED++))
fi

# Check Cluster Status
echo ""
echo "Checking cluster status..."
ARGOCD_STATUS=$(aws eks describe-cluster --name $ARGOCD_CLUSTER --region $REGION --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
if [ "$ARGOCD_STATUS" = "ACTIVE" ]; then
    check_status "ArgoCD cluster is ACTIVE"
else
    echo -e "${RED}✗${NC} ArgoCD cluster status: $ARGOCD_STATUS (expected: ACTIVE)"
    ((FAILED++))
fi

WORKLOAD_STATUS=$(aws eks describe-cluster --name $WORKLOAD_CLUSTER --region $REGION --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
if [ "$WORKLOAD_STATUS" = "ACTIVE" ]; then
    check_status "Workload cluster is ACTIVE"
else
    echo -e "${RED}✗${NC} Workload cluster status: $WORKLOAD_STATUS (expected: ACTIVE)"
    ((FAILED++))
fi

# Check Public Endpoint Access (CRITICAL)
echo ""
echo "Checking cluster endpoint access..."
ARGOCD_PUBLIC=$(aws eks describe-cluster --name $ARGOCD_CLUSTER --region $REGION --query 'cluster.resourcesVpcConfig.endpointPublicAccess' --output text 2>/dev/null || echo "false")
if [ "$ARGOCD_PUBLIC" = "True" ]; then
    check_status "ArgoCD cluster has public endpoint enabled"
else
    echo -e "${RED}✗${NC} ArgoCD cluster public endpoint: $ARGOCD_PUBLIC (expected: True)"
    echo -e "${YELLOW}⚠${NC}  This will prevent GitHub Actions from accessing the cluster"
    ((FAILED++))
fi

WORKLOAD_PUBLIC=$(aws eks describe-cluster --name $WORKLOAD_CLUSTER --region $REGION --query 'cluster.resourcesVpcConfig.endpointPublicAccess' --output text 2>/dev/null || echo "false")
if [ "$WORKLOAD_PUBLIC" = "True" ]; then
    check_status "Workload cluster has public endpoint enabled"
else
    echo -e "${RED}✗${NC} Workload cluster public endpoint: $WORKLOAD_PUBLIC (expected: True)"
    echo -e "${YELLOW}⚠${NC}  This will prevent GitHub Actions from accessing the cluster"
    ((FAILED++))
fi

# Check ECR Repositories
echo ""
echo "Checking ECR repositories..."
ECR_BACKEND=$(aws ecr describe-repositories --repository-names ${APP_IDENTIFIER}-backend --region $REGION --query 'repositories[0].repositoryName' --output text 2>/dev/null || echo "")
if [ "$ECR_BACKEND" = "${APP_IDENTIFIER}-backend" ]; then
    check_status "ECR backend repository exists"
else
    echo -e "${RED}✗${NC} ECR backend repository not found"
    ((FAILED++))
fi

ECR_FRONTEND=$(aws ecr describe-repositories --repository-names ${APP_IDENTIFIER}-frontend --region $REGION --query 'repositories[0].repositoryName' --output text 2>/dev/null || echo "")
if [ "$ECR_FRONTEND" = "${APP_IDENTIFIER}-frontend" ]; then
    check_status "ECR frontend repository exists"
else
    echo -e "${RED}✗${NC} ECR frontend repository not found"
    ((FAILED++))
fi

# Check IAM Role
echo ""
echo "Checking IAM role..."
IAM_ROLE=$(aws iam get-role --role-name ${APP_IDENTIFIER}-external-dns --query 'Role.RoleName' --output text 2>/dev/null || echo "")
if [ "$IAM_ROLE" = "${APP_IDENTIFIER}-external-dns" ]; then
    check_status "ExternalDNS IAM role exists"
else
    echo -e "${RED}✗${NC} ExternalDNS IAM role not found"
    ((FAILED++))
fi

# Check S3 Backend
echo ""
echo "Checking S3 backend..."
S3_BUCKET=$(aws s3 ls s3://${APP_IDENTIFIER}-tfstate --region $REGION 2>/dev/null && echo "exists" || echo "")
if [ "$S3_BUCKET" = "exists" ]; then
    check_status "S3 backend bucket exists"
else
    echo -e "${RED}✗${NC} S3 backend bucket not found"
    ((FAILED++))
fi

# Check DynamoDB Lock Table
echo ""
echo "Checking DynamoDB lock table..."
DDB_TABLE=$(aws dynamodb describe-table --table-name ${APP_IDENTIFIER}-tfstate-lock --region $REGION --query 'Table.TableName' --output text 2>/dev/null || echo "")
if [ "$DDB_TABLE" = "${APP_IDENTIFIER}-tfstate-lock" ]; then
    check_status "DynamoDB lock table exists"
else
    echo -e "${RED}✗${NC} DynamoDB lock table not found"
    ((FAILED++))
fi

echo ""
echo "=== Phase 2: Kubernetes Resources ==="
echo ""

# Check ArgoCD (if kubectl is configured)
echo "Checking ArgoCD installation..."
if aws eks update-kubeconfig --name $ARGOCD_CLUSTER --region $REGION 2>/dev/null; then
    if kubectl get namespace argocd 2>/dev/null >/dev/null; then
        check_status "ArgoCD namespace exists"
        
        ARGOCD_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep Running | wc -l || echo "0")
        if [ "$ARGOCD_PODS" -gt "0" ]; then
            check_status "ArgoCD pods are running ($ARGOCD_PODS pods)"
        else
            echo -e "${RED}✗${NC} No ArgoCD pods in Running state"
            ((FAILED++))
        fi
        
        if kubectl get deployment argocd-server -n argocd 2>/dev/null >/dev/null; then
            check_status "ArgoCD server deployment exists"
        else
            echo -e "${RED}✗${NC} ArgoCD server deployment not found"
            ((FAILED++))
        fi
    else
        echo -e "${YELLOW}⚠${NC}  ArgoCD namespace not found (may not be installed yet)"
    fi
else
    echo -e "${YELLOW}⚠${NC}  Cannot connect to ArgoCD cluster (check endpoint access)"
fi

# Check ExternalDNS (if kubectl is configured)
echo ""
echo "Checking ExternalDNS installation..."
if aws eks update-kubeconfig --name $WORKLOAD_CLUSTER --region $REGION 2>/dev/null; then
    if kubectl get serviceaccount external-dns -n kube-system 2>/dev/null >/dev/null; then
        check_status "ExternalDNS ServiceAccount exists"
        
        EXTERNALDNS_PODS=$(kubectl get pods -n kube-system -l app=external-dns --no-headers 2>/dev/null | grep Running | wc -l || echo "0")
        if [ "$EXTERNALDNS_PODS" -gt "0" ]; then
            check_status "ExternalDNS pods are running ($EXTERNALDNS_PODS pods)"
        else
            echo -e "${RED}✗${NC} No ExternalDNS pods in Running state"
            ((FAILED++))
        fi
        
        if kubectl get deployment external-dns -n kube-system 2>/dev/null >/dev/null; then
            check_status "ExternalDNS deployment exists"
        else
            echo -e "${RED}✗${NC} ExternalDNS deployment not found"
            ((FAILED++))
        fi
    else
        echo -e "${YELLOW}⚠${NC}  ExternalDNS ServiceAccount not found (may not be installed yet)"
    fi
else
    echo -e "${YELLOW}⚠${NC}  Cannot connect to Workload cluster (check endpoint access)"
fi

echo ""
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Infrastructure is ready.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review the errors above.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Check GitHub Actions workflow status:"
    echo "   https://github.com/akhilsathwik/prospectf-opsera/actions/workflows/prospectf500-app1-infra.yaml"
    echo "2. If clusters don't have public endpoints, re-run Terraform apply"
    echo "3. If ArgoCD/ExternalDNS not installed, check installation job logs"
    exit 1
fi
