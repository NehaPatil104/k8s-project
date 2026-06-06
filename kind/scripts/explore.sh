#!/bin/bash
# =============================================================================
# explore.sh — Handy kubectl commands to explore and understand the cluster.
# Run individual sections as you learn each concept.
# =============================================================================

NS="ecommerce"

echo ""
echo "=== NODES ==="
kubectl get nodes -o wide

echo ""
echo "=== NAMESPACES ==="
kubectl get namespaces

echo ""
echo "=== RESOURCE QUOTA ==="
kubectl describe resourcequota -n $NS

echo ""
echo "=== LIMIT RANGE ==="
kubectl describe limitrange -n $NS

echo ""
echo "=== ALL PODS (with node placement) ==="
kubectl get pods -n $NS -o wide

echo ""
echo "=== DEPLOYMENTS ==="
kubectl get deployments -n $NS

echo ""
echo "=== STATEFULSETS ==="
kubectl get statefulsets -n $NS

echo ""
echo "=== SERVICES ==="
kubectl get services -n $NS

echo ""
echo "=== INGRESS ==="
kubectl get ingress -n $NS

echo ""
echo "=== HPA ==="
kubectl get hpa -n $NS

echo ""
echo "=== PDB ==="
kubectl get pdb -n $NS

echo ""
echo "=== PERSISTENT VOLUMES ==="
kubectl get pv

echo ""
echo "=== PERSISTENT VOLUME CLAIMS ==="
kubectl get pvc -n $NS

echo ""
echo "=== CRONJOBS ==="
kubectl get cronjobs -n $NS

echo ""
echo "=== JOBS ==="
kubectl get jobs -n $NS

echo ""
echo "=== SERVICE ACCOUNTS ==="
kubectl get serviceaccounts -n $NS

echo ""
echo "=== RBAC ROLES ==="
kubectl get roles -n $NS
kubectl get rolebindings -n $NS

echo ""
echo "=== NETWORK POLICIES ==="
kubectl get networkpolicies -n $NS

echo ""
echo "=== EVENTS (last 20) ==="
kubectl get events -n $NS --sort-by='.lastTimestamp' | tail -20
