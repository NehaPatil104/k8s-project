#!/bin/bash
# =============================================================================
# teardown.sh — Destroy everything to avoid AWS charges
#
# IMPORTANT: Run this when you're done learning to avoid ongoing AWS costs.
# EKS cluster costs ~$0.10/hr + EC2 nodes (~$0.05/hr each for t3.small)
# Total: ~$5-10/day if left running
# =============================================================================
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=============================================="
echo " WARNING: This will delete EVERYTHING"
echo " EKS cluster, VPC, all AWS resources"
echo "=============================================="
read -p "Are you sure? Type 'yes' to continue: " confirm
[ "$confirm" != "yes" ] && echo "Aborted." && exit 0

# Delete K8s resources first (especially the Ingress — so ALB gets deleted)
# If we delete the VPC first, the ALB deletion gets stuck
echo ""
echo "Deleting Kubernetes resources..."
kubectl delete namespace ecommerce --ignore-not-found
kubectl delete -f k8s/ingress/ --ignore-not-found

echo "Waiting for ALB to be deleted..."
sleep 30

# Destroy Terraform infrastructure
echo "Destroying AWS infrastructure..."
cd "$PROJECT_ROOT/terraform"
terraform destroy -auto-approve

echo ""
echo "All resources deleted. No more AWS charges."
