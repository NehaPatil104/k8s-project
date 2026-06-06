#!/bin/bash
# Tear down the Kind cluster and all resources
set -e
CLUSTER_NAME="ecommerce-cluster"
echo "Deleting Kind cluster '${CLUSTER_NAME}'..."
kind delete cluster --name "$CLUSTER_NAME"
echo "Done. All resources removed."
