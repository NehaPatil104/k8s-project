#!/bin/bash
# =============================================================================
# setup-kind.sh — Bootstrap the Online Boutique on a local Kind cluster
# Run once. Re-running is safe (idempotent).
# =============================================================================
set -e

CLUSTER_NAME="ecommerce-cluster"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=============================================="
echo " Online Boutique — Kind Setup"
echo " Project: $PROJECT_ROOT"
echo "=============================================="

# --- Step 1: Prerequisites ---
echo ""
echo "[1/9] Checking prerequisites..."
for tool in kind kubectl docker; do
  if ! command -v $tool &>/dev/null; then
    echo "  ERROR: '$tool' not found. Install it first."
    echo "  kind:    https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    echo "  kubectl: https://kubernetes.io/docs/tasks/tools/"
    echo "  docker:  https://www.docker.com/products/docker-desktop"
    exit 1
  fi
done
echo "  ✓ All tools found"

# --- Step 2: Create Kind cluster ---
echo ""
echo "[2/9] Creating Kind cluster (1 control-plane + 3 workers)..."
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "  Cluster '${CLUSTER_NAME}' already exists, skipping."
else
  kind create cluster --config "$PROJECT_ROOT/kind-config.yaml"
  echo "  ✓ Cluster created"
fi
kubectl config use-context "kind-${CLUSTER_NAME}"

# --- Step 3: NGINX Ingress Controller ---
echo ""
echo "[3/9] Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# The Kind manifest nodeSelector only has kubernetes.io/os=linux — no ingress-ready=true.
# Without this patch the ingress controller can land on any node, but port 80 is only
# mapped on the control-plane. So we force it onto control-plane via nodeSelector.
kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"ingress-ready":"true","kubernetes.io/os":"linux"}}]'

echo "  Waiting for ingress controller on control-plane..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s
echo "  ✓ NGINX Ingress ready on control-plane"

# --- Step 4: Metrics Server (for HPA) ---
echo ""
echo "[4/9] Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' \
  2>/dev/null || true
echo "  ✓ Metrics Server installed"

# --- Step 5: Namespaces + Quotas ---
echo ""
echo "[5/9] Creating namespaces and resource quotas..."
kubectl apply -f "$PROJECT_ROOT/k8s/namespaces/"
echo "  ✓ Done"

# --- Step 6: RBAC ---
echo ""
echo "[6/9] Applying RBAC..."
kubectl apply -f "$PROJECT_ROOT/k8s/rbac/"
echo "  ✓ Done"

# --- Step 7: Config + Stateful workloads ---
echo ""
echo "[7/9] Deploying config and stateful workloads..."
kubectl apply -f "$PROJECT_ROOT/k8s/configmaps/"
kubectl apply -f "$PROJECT_ROOT/k8s/statefulsets/"
echo "  Waiting for Redis..."
kubectl rollout status statefulset/redis-cart -n ecommerce --timeout=120s
echo "  ✓ Redis ready"

# --- Step 8: Application services ---
echo ""
echo "[8/9] Deploying Online Boutique services..."
kubectl apply -f "$PROJECT_ROOT/k8s/deployments/"
kubectl apply -f "$PROJECT_ROOT/k8s/services/"
kubectl apply -f "$PROJECT_ROOT/k8s/ingress/"
kubectl apply -f "$PROJECT_ROOT/k8s/hpa/"
kubectl apply -f "$PROJECT_ROOT/k8s/pdb/"
kubectl apply -f "$PROJECT_ROOT/k8s/cronjobs/"

echo "  Waiting for all deployments (this may take 2-3 minutes while images pull)..."
for svc in frontend cartservice productcatalogservice checkoutservice paymentservice \
           shippingservice currencyservice emailservice recommendationservice adservice; do
  kubectl rollout status deployment/$svc -n ecommerce --timeout=300s
done
echo "  ✓ All services running"

# --- Step 9: Smoke test ---
echo ""
echo "[9/9] Running smoke test job..."
kubectl apply -f "$PROJECT_ROOT/k8s/jobs/"
kubectl wait --for=condition=complete job/smoke-test-job -n ecommerce --timeout=120s 2>/dev/null \
  && kubectl logs -l app=smoke-test -n ecommerce \
  || echo "  (Smoke test timed out — services may still be warming up)"

echo ""
echo "=============================================="
echo " Setup complete!"
echo "=============================================="
echo ""
echo "Add this to your hosts file:"
echo "  Windows (as Admin): C:\\Windows\\System32\\drivers\\etc\\hosts"
echo "  Mac/Linux: /etc/hosts"
echo ""
echo "  127.0.0.1  ecommerce.local"
echo ""
echo "Then open: http://ecommerce.local"
echo "     or:   http://localhost:30080  (NodePort, no hosts file needed)"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n ecommerce -o wide     # See pod placement across nodes"
echo "  kubectl get hpa -n ecommerce -w           # Watch autoscaling"
echo "  kubectl top pods -n ecommerce             # Resource usage"
echo "  bash scripts/explore.sh                   # Full cluster overview"
