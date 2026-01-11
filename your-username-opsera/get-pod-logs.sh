#!/bin/bash
# Script to get frontend pod logs and diagnose issues

set -e

NAMESPACE="your-username-dev"
APP_NAME="your-username"

echo "=== Frontend Pod Status ==="
kubectl get pods -n $NAMESPACE -l app=${APP_NAME}-frontend

echo ""
echo "=== Frontend Pod Events ==="
kubectl get events -n $NAMESPACE --field-selector involvedObject.kind=Pod --sort-by='.lastTimestamp' | grep frontend | tail -20

echo ""
echo "=== Frontend Pod Details ==="
for pod in $(kubectl get pods -n $NAMESPACE -l app=${APP_NAME}-frontend -o jsonpath='{.items[*].metadata.name}'); do
  echo "--- Pod: $pod ---"
  kubectl describe pod $pod -n $NAMESPACE | grep -A 20 "Events:" || true
  echo ""
done

echo ""
echo "=== Frontend Pod Logs ==="
for pod in $(kubectl get pods -n $NAMESPACE -l app=${APP_NAME}-frontend -o jsonpath='{.items[*].metadata.name}'); do
  echo "--- Logs from Pod: $pod ---"
  kubectl logs $pod -n $NAMESPACE --tail=100 || true
  echo ""
done

echo ""
echo "=== Frontend Pod Environment Variables ==="
for pod in $(kubectl get pods -n $NAMESPACE -l app=${APP_NAME}-frontend -o jsonpath='{.items[*].metadata.name}'); do
  echo "--- Env from Pod: $pod ---"
  kubectl exec $pod -n $NAMESPACE -- env | grep BACKEND || true
  echo ""
done

echo ""
echo "=== Checking nginx config in pod ==="
for pod in $(kubectl get pods -n $NAMESPACE -l app=${APP_NAME}-frontend -o jsonpath='{.items[*].metadata.name}'); do
  echo "--- nginx config from Pod: $pod ---"
  kubectl exec $pod -n $NAMESPACE -- cat /etc/nginx/conf.d/default.conf 2>/dev/null || echo "Cannot read config"
  echo ""
done

echo ""
echo "=== Testing nginx config ==="
for pod in $(kubectl get pods -n $NAMESPACE -l app=${APP_NAME}-frontend -o jsonpath='{.items[*].metadata.name}'); do
  echo "--- nginx -t from Pod: $pod ---"
  kubectl exec $pod -n $NAMESPACE -- nginx -t 2>&1 || true
  echo ""
done
