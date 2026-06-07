#!/bin/bash
# =============================================================================
# setup-helm.sh — Bootstrap the Online Boutique on Kind using Helm
#
# Difference from setup-kind.sh:
#   setup-kind.sh  → applies raw kubectl manifests from k8s/ folder
#   setup-helm.sh  → deploys everything via the Helm chart in helm/ecommerce/
#
# Both deploy the same app — this script is for learning Helm.
# =============================================================================
set -e

CLUSTER_NAME="ecommerce-cluster"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HELM_CHART="$PROJECT_ROOT/helm/ecommerce"

echo "=============================================="
echo " Online Boutique — Helm Setup on Kind"
echo "=============================================="

# --- Step 1: Prerequisites ---
echo ""
echo "[1/6] Checking prerequisites..."
for tool in kind kubectl docker helm; do
  if ! command -v $tool &>/dev/null; then
    echo "  ERROR: '$tool' not found."
    case $tool in
      kind)  echo "  Install: winget install Kubernetes.kind" ;;
      kubectl) echo "  Install: winget install Kubernetes.kubectl" ;;
      docker) echo "  Install: https://www.docker.com/products/docker-desktop" ;;
      helm)  echo "  Install: winget install Helm.Helm" ;;
    esac
    exit 1
  fi
done
echo "  ✓ kind, kubectl, docker, helm — all found"

# --- Step 2: Create Kind cluster ---
echo ""
echo "[2/6] Setting up Kind cluster..."
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "  Cluster '${CLUSTER_NAME}' already exists, skipping creation."
else
  echo "  Creating cluster (1 control-plane + 3 workers)..."
  kind create cluster --config "$PROJECT_ROOT/kind-config.yaml"
  echo "  ✓ Cluster created"
fi
kubectl config use-context "kind-${CLUSTER_NAME}"
echo "  ✓ kubectl context set to kind-${CLUSTER_NAME}"

# --- Step 3: Install NGINX Ingress Controller ---
echo ""
echo "[3/6] Installing NGINX Ingress Controller..."
if kubectl get namespace ingress-nginx &>/dev/null; then
  echo "  NGINX Ingress already installed, skipping."
else
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

  echo "  Waiting for ingress admission jobs to complete..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=complete job/ingress-nginx-admission-create \
    --timeout=60s || true
  kubectl wait --namespace ingress-nginx \
    --for=condition=complete job/ingress-nginx-admission-patch \
    --timeout=60s || true

  # The Kind manifest only has nodeSelector: kubernetes.io/os=linux
  # which means the ingress controller can land on ANY node.
  # We must patch it to also require ingress-ready=true so it always
  # lands on the control-plane — the only node with port 80 mapped.
  echo "  Patching ingress nodeSelector to pin to control-plane..."
  kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
    --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"ingress-ready":"true","kubernetes.io/os":"linux"}}]'

  echo "  Waiting for ingress controller pod to be ready..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=180s
  echo "  ✓ NGINX Ingress ready on control-plane"
fi

# --- Step 4: Lint the Helm chart ---
echo ""
echo "[4/6] Linting Helm chart..."
helm lint "$HELM_CHART"
echo "  ✓ Chart is valid"

# --- Step 5: Deploy with Helm ---
echo ""
echo "[5/6] Deploying with Helm..."

# Check if release already exists
if helm list | grep -q "^ecommerce"; then
  echo "  Release 'ecommerce' already exists."
  echo "  Running helm upgrade instead..."
  helm upgrade ecommerce "$HELM_CHART"
  echo "  ✓ Helm upgrade complete (revision $(helm list | grep ecommerce | awk '{print $3}'))"
else
  echo "  Running helm install..."
  helm install ecommerce "$HELM_CHART"
  echo "  ✓ Helm install complete"
fi

# --- Step 6: Wait and verify ---
echo ""
echo "[6/6] Waiting for all pods to be ready..."
echo "  (This may take 3-5 minutes while images are pulled)"
echo ""

# Wait for namespace to exist first
sleep 5

for svc in frontend cartservice productcatalogservice checkoutservice paymentservice \
           shippingservice currencyservice emailservice recommendationservice adservice; do
  echo "  Waiting for $svc..."
  kubectl rollout status deployment/$svc -n ecommerce --timeout=300s
done

echo ""
echo "=============================================="
echo " Helm Deployment Complete!"
echo "=============================================="
echo ""
echo "Helm release info:"
helm list
echo ""
echo "Add to your hosts file (run Notepad as Admin on Windows):"
echo "  C:\\Windows\\System32\\drivers\\etc\\hosts"
echo "  127.0.0.1  ecommerce.local"
echo ""
echo "Access the app:"
echo "  http://ecommerce.local       (after hosts file update)"
echo "  http://localhost:30080       (NodePort — no hosts file needed)"
echo ""
echo "Useful Helm commands:"
echo "  helm list                                           # See release status"
echo "  helm status ecommerce                              # Detailed release info"
echo "  helm history ecommerce                             # Release history"
echo "  helm upgrade ecommerce helm/ecommerce --set frontend.replicas=3"
echo "  helm rollback ecommerce 1                          # Roll back to revision 1"
echo "  helm uninstall ecommerce                           # Remove everything"
echo ""
echo "Useful kubectl commands:"
echo "  kubectl get pods -n ecommerce -o wide              # Pod placement"
echo "  kubectl get hpa -n ecommerce -w                    # Watch autoscaling"
echo "  kubectl top pods -n ecommerce                      # Resource usage"
