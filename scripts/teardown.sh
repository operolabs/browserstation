#!/bin/bash
set -euo pipefail

echo "Tearing down BrowserStation..."

# Delete Ray cluster and all services
echo "Deleting RayService..."
kubectl delete rayservice browser-cluster -n ray-system --force --grace-period=0 2>/dev/null || true
echo "Deleting services..."
kubectl delete svc --all -n ray-system --force --grace-period=0 2>/dev/null || true

# Uninstall KubeRay operator
echo "Uninstalling KubeRay operator..."
helm uninstall kuberay-operator -n ray-system 2>/dev/null || true

# Clean up namespace
echo "Deleting namespace..."
kubectl delete namespace ray-system --force --grace-period=0 2>/dev/null || true

# Delete Kind cluster
echo "Deleting Kind cluster..."
kind delete cluster --name browserstation

echo "Teardown complete!"