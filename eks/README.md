# Online Boutique — EKS Deployment

Same app as the Kind setup, deployed on real AWS infrastructure.

---

## What's Different from Kind

| | Kind (local) | EKS (AWS) |
|---|---|---|
| Cluster | Docker containers | Real EC2 nodes |
| Storage | Local node filesystem | AWS EBS gp3 volumes |
| Ingress | NGINX pod | AWS Application Load Balancer |
| Node provisioning | kind-config.yaml | Terraform |
| Secrets | Plain base64 | KMS-encrypted etcd |
| Auth | None needed | IRSA (IAM Roles for ServiceAccounts) |
| Cost | Free | ~$5-10/day |
| Access URL | localhost | Real public ALB DNS |

---

## Prerequisites

```bash
# 1. AWS CLI
# Download: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
aws configure   # Enter your Access Key, Secret Key, region, output format

# 2. Terraform
# Download: https://developer.hashicorp.com/terraform/install
terraform -version

# 3. kubectl + helm
# kubectl: https://kubernetes.io/docs/tasks/tools/
# helm:    https://helm.sh/docs/intro/install/
```

---

## Deploy

```bash
# Full automated setup
bash scripts/setup-eks.sh

# App will be available at the ALB URL printed at the end
# e.g.: http://k8s-ecommerce-xxxxx.us-east-1.elb.amazonaws.com
```

---

## Manual Step-by-Step

```bash
# 1. Provision AWS infrastructure
cd terraform
terraform init
terraform apply

# 2. Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name ecommerce-cluster

# 3. Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=ecommerce-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# 4. Deploy everything
kubectl apply -f k8s/namespaces/
kubectl apply -f k8s/rbac/
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/configmaps/
kubectl apply -f k8s/storage/
kubectl apply -f k8s/statefulsets/
kubectl apply -f k8s/deployments/
kubectl apply -f k8s/services/
kubectl apply -f k8s/ingress/
kubectl apply -f k8s/hpa/
kubectl apply -f k8s/pdb/
kubectl apply -f k8s/cronjobs/

# 5. Get the ALB URL
kubectl get ingress -n ecommerce
```

---

## Key EKS Concepts

### IRSA (IAM Roles for Service Accounts)
Pods get AWS permissions without storing credentials as Secrets.
```
Pod → ServiceAccount → IAM Role → AWS APIs
```

### EBS CSI Driver
Allows K8s PersistentVolumeClaims to provision real AWS EBS volumes.
```
PVC created → EBS CSI driver → AWS creates EBS volume → mounts to pod
```

### AWS Load Balancer Controller
Watches Ingress objects and creates real AWS ALBs automatically.
```
kubectl apply ingress.yaml → ALB controller → AWS ALB created → traffic routes to pods
```

---

## Cost Management

```bash
# Check what's running
kubectl get nodes
aws eks list-clusters

# IMPORTANT: Destroy when done to avoid charges
bash scripts/teardown.sh
```

**Estimated costs:**
- EKS control plane: $0.10/hr (~$2.40/day)
- t3.medium nodes (x2): ~$0.09/hr (~$2.16/day)
- t3.small node (x1): ~$0.02/hr (~$0.50/day)
- NAT Gateway: ~$0.045/hr (~$1.08/day)
- **Total: ~$6-7/day**

---

## Teardown

```bash
# Deletes everything — cluster, nodes, VPC, ALB
bash scripts/teardown.sh
```
