#!/bin/bash
# =============================================================================
# setup-eks.sh — Provision EKS cluster and deploy Online Boutique
#
# What this script does:
#   1. Provisions AWS infrastructure with Terraform (VPC + EKS + Node Groups)
#   2. Installs AWS Load Balancer Controller (replaces NGINX Ingress)
#   3. Deploys all Kubernetes manifests
#   4. Prints the ALB URL to access the app
#
# Prerequisites:
#   - AWS CLI:    https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
#   - Terraform:  https://developer.hashicorp.com/terraform/install
#   - kubectl:    https://kubernetes.io/docs/tasks/tools/
#   - helm:       https://helm.sh/docs/intro/install/
#   - eksctl:     https://eksctl.io/installation/  (optional, for node management)
#
# Configure AWS credentials first:
#   aws configure
#   # Enter: Access Key ID, Secret Access Key, region (us-east-1), output format (json)
# =============================================================================
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="ecommerce-cluster"
AWS_REGION="us-east-1"

echo "=============================================="
echo " Online Boutique — EKS Setup"
echo "=============================================="

# --- Step 1: Prerequisites ---
echo ""
echo "[1/8] Checking prerequisites..."
for tool in aws terraform kubectl helm; do
  if ! command -v $tool &>/dev/null; then
    echo "  ERROR: '$tool' not found."
    exit 1
  fi
done

# Verify AWS credentials are configured
if ! aws sts get-caller-identity &>/dev/null; then
  echo "  ERROR: AWS credentials not configured. Run: aws configure"
  exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "  ✓ AWS Account: $AWS_ACCOUNT_ID"
echo "  ✓ Region: $AWS_REGION"

# --- Step 2: Provision infrastructure with Terraform ---
echo ""
echo "[2/8] Provisioning AWS infrastructure (VPC + EKS)..."
echo "  This takes 15-20 minutes..."
cd "$PROJECT_ROOT/terraform"
terraform init
terraform apply -auto-approve
echo "  ✓ Infrastructure ready"

# --- Step 3: Configure kubectl ---
echo ""
echo "[3/8] Configuring kubectl..."
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
kubectl cluster-info
echo "  ✓ kubectl configured"

# Get the ALB controller role ARN from Terraform output
ALB_ROLE_ARN=$(terraform output -raw alb_controller_role_arn)
cd "$PROJECT_ROOT"

# --- Step 4: Install AWS Load Balancer Controller ---
# This replaces NGINX Ingress on EKS.
# It watches Ingress objects and creates real AWS ALBs automatically.
echo ""
echo "[4/8] Installing AWS Load Balancer Controller..."

# Add the EKS Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Create the ServiceAccount with the IAM role annotation (IRSA)
# This is what gives the controller permission to create ALBs in your AWS account
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    # This annotation links the K8s ServiceAccount to the AWS IAM Role
    # The pod uses this role to call AWS APIs (create ALB, target groups, etc.)
    eks.amazonaws.com/role-arn: ${ALB_ROLE_ARN}
EOF

# Install the controller via Helm
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$AWS_REGION \
  --set vpcId=$(cd terraform && terraform output -raw vpc_id)

echo "  Waiting for ALB controller..."
kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s
echo "  ✓ AWS Load Balancer Controller installed"

# --- Step 5: Foundation ---
echo ""
echo "[5/8] Applying foundation (namespaces, RBAC, config)..."
kubectl apply -f k8s/namespaces/
kubectl apply -f k8s/rbac/
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/configmaps/
kubectl apply -f k8s/storage/
echo "  ✓ Done"

# --- Step 6: Stateful workloads ---
echo ""
echo "[6/8] Deploying Redis (EBS-backed StatefulSet)..."
kubectl apply -f k8s/statefulsets/
echo "  Waiting for Redis..."
kubectl rollout status statefulset/redis-cart -n ecommerce --timeout=120s
echo "  ✓ Redis ready"

# --- Step 7: Application ---
echo ""
echo "[7/8] Deploying application services..."
kubectl apply -f k8s/deployments/
kubectl apply -f k8s/services/
kubectl apply -f k8s/ingress/
kubectl apply -f k8s/hpa/
kubectl apply -f k8s/pdb/
kubectl apply -f k8s/cronjobs/

echo "  Waiting for deployments..."
for svc in frontend cartservice productcatalogservice checkoutservice paymentservice \
           shippingservice currencyservice emailservice recommendationservice adservice; do
  kubectl rollout status deployment/$svc -n ecommerce --timeout=300s
done
echo "  ✓ All services running"

# --- Step 8: Get the ALB URL ---
echo ""
echo "[8/8] Getting ALB URL..."
echo "  Waiting for ALB to be provisioned (this takes ~2 minutes)..."
sleep 30

ALB_URL=""
for i in {1..20}; do
  ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
  if [ -n "$ALB_URL" ]; then
    break
  fi
  echo "  Waiting for ALB... ($i/20)"
  sleep 15
done

echo ""
echo "=============================================="
echo " EKS Deployment Complete!"
echo "=============================================="
echo ""
if [ -n "$ALB_URL" ]; then
  echo "  App URL: http://$ALB_URL"
else
  echo "  ALB still provisioning. Check later:"
  echo "  kubectl get ingress -n ecommerce"
fi
echo ""
echo "  kubectl get nodes                          # See your EC2 nodes"
echo "  kubectl get pods -n ecommerce -o wide      # Pod placement"
echo "  kubectl get ingress -n ecommerce           # ALB URL"
echo "  kubectl top nodes                          # Node resource usage"
echo "  kubectl top pods -n ecommerce              # Pod resource usage"
