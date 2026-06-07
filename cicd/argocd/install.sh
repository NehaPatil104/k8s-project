#!/bin/bash
# =============================================================================
# install.sh — Install ArgoCD on the Kind cluster
#
# ArgoCD is a GitOps CD tool — it watches your git repo and keeps
# the cluster in sync with whatever is in git.
#
# After running this script:
#   1. ArgoCD is running in the argocd namespace
#   2. You can access the UI at http://localhost:8080
#   3. The ecommerce app is registered and auto-syncing
# =============================================================================
set -e

GITHUB_REPO="https://github.com/NehaPatil104/k8s-project.git"
ARGOCD_VERSION="v2.9.3"

echo "=============================================="
echo " Installing ArgoCD on Kind cluster"
echo "=============================================="

# --- Step 1: Verify cluster is running ---
echo ""
echo "[1/5] Checking cluster..."
kubectl cluster-info || { echo "ERROR: No cluster running. Run setup-helm.sh first."; exit 1; }
echo "  ✓ Cluster is running"

# --- Step 2: Install ArgoCD ---
echo ""
echo "[2/5] Installing ArgoCD ${ARGOCD_VERSION}..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

echo "  Waiting for ArgoCD pods to be ready (this takes ~2 minutes)..."
kubectl wait --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --namespace=argocd \
  --timeout=300s
echo "  ✓ ArgoCD installed"

# --- Step 3: Install ArgoCD CLI ---
echo ""
echo "[3/5] ArgoCD CLI install (optional)..."
echo "  To install ArgoCD CLI on Windows:"
echo "  winget install ArgoProj.ArgoCD"
echo "  or download from: https://github.com/argoproj/argo-cd/releases"

# --- Step 4: Create ArgoCD Application ---
echo ""
echo "[4/5] Creating ArgoCD Application..."
kubectl apply -f "$(dirname "$0")/application.yaml"
echo "  ✓ ArgoCD Application created"

# --- Step 5: Get credentials and access info ---
echo ""
echo "[5/5] Getting access credentials..."

# Port-forward ArgoCD server (run in background)
echo "  Starting port-forward to ArgoCD UI..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
PF_PID=$!
sleep 3

# Get initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "=============================================="
echo " ArgoCD is ready!"
echo "=============================================="
echo ""
echo "  UI:       https://localhost:8080"
echo "  Username: admin"
echo "  Password: ${ARGOCD_PASSWORD}"
echo ""
echo "  (Click 'Advanced' → 'Proceed' if browser warns about certificate)"
echo ""
echo "  ArgoCD is now watching:"
echo "  ${GITHUB_REPO}"
echo ""
echo "  Every push to main will automatically sync to the cluster!"
echo ""
echo "  To stop port-forward: kill ${PF_PID}"
echo "  To restart port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
