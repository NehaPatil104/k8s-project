# Kubernetes Learning Project — Online Boutique

Production-style K8s manifests wrapping Google's [Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) microservices demo.
All K8s YAML is written from scratch to cover the full breadth of concepts.

---

## Architecture

```
                         [Ingress - NGINX]
                                |
                         [frontend :8080]
                        /    |    |    \
          [productcatalog] [cart] [checkout] [recommendation] [currency] [ad]
                              |       |
                           [Redis] [payment] [shipping] [email]
```

11 real microservices (Go, Python, Node.js, Java, C#) communicating over **gRPC**.

---

## Prerequisites

| Tool | Install |
|------|---------|
| Docker Desktop | https://www.docker.com/products/docker-desktop |
| kind | `winget install Kubernetes.kind` |
| kubectl | `winget install Kubernetes.kubectl` |
| helm *(optional)* | `winget install Helm.Helm` |

---

## Quick Start

```bash
# 1. Create cluster + deploy everything
bash scripts/setup-kind.sh

# 2. Add to hosts file (run Notepad as Administrator on Windows):
#    C:\Windows\System32\drivers\etc\hosts
#    127.0.0.1  ecommerce.local

# 3. Open the store:
#    http://ecommerce.local
#    http://localhost:30080   (no hosts file needed)
```

---

## Kubernetes Concepts Map

| Concept | File |
|---------|------|
| Multi-node cluster, Taints | [`kind-config.yaml`](kind-config.yaml) |
| Namespaces | [`k8s/namespaces/namespaces.yaml`](k8s/namespaces/namespaces.yaml) |
| ResourceQuota | [`k8s/namespaces/resource-quota.yaml`](k8s/namespaces/resource-quota.yaml) |
| LimitRange | [`k8s/namespaces/resource-quota.yaml`](k8s/namespaces/resource-quota.yaml) |
| ServiceAccounts | [`k8s/rbac/service-accounts.yaml`](k8s/rbac/service-accounts.yaml) |
| Roles + RoleBindings | [`k8s/rbac/roles.yaml`](k8s/rbac/roles.yaml) |
| StorageClass | [`k8s/storage/storage-class.yaml`](k8s/storage/storage-class.yaml) |
| ConfigMap (env vars) | [`k8s/configmaps/services-config.yaml`](k8s/configmaps/services-config.yaml) |
| StatefulSet + PVC | [`k8s/statefulsets/redis-cart.yaml`](k8s/statefulsets/redis-cart.yaml) |
| Tolerations + NodeAffinity | [`k8s/statefulsets/redis-cart.yaml`](k8s/statefulsets/redis-cart.yaml) |
| Deployment + Rolling Update | [`k8s/deployments/frontend.yaml`](k8s/deployments/frontend.yaml) |
| Init Containers | [`k8s/deployments/cartservice.yaml`](k8s/deployments/cartservice.yaml), [`loadgenerator.yaml`](k8s/deployments/loadgenerator.yaml) |
| Startup / Liveness / Readiness Probes | All deployments |
| Pod Anti-Affinity | [`k8s/deployments/frontend.yaml`](k8s/deployments/frontend.yaml), cartservice |
| Downward API | [`k8s/deployments/frontend.yaml`](k8s/deployments/frontend.yaml) |
| SecurityContext | All deployments |
| ClusterIP Service | [`k8s/services/services.yaml`](k8s/services/services.yaml) |
| NodePort Service | [`k8s/services/services.yaml`](k8s/services/services.yaml) |
| Ingress + routing | [`k8s/ingress/ingress.yaml`](k8s/ingress/ingress.yaml) |
| HPA (CPU autoscaling) | [`k8s/hpa/hpa.yaml`](k8s/hpa/hpa.yaml) |
| PodDisruptionBudget | [`k8s/pdb/pdb.yaml`](k8s/pdb/pdb.yaml) |
| Job | [`k8s/jobs/seed-job.yaml`](k8s/jobs/seed-job.yaml) |
| CronJob | [`k8s/cronjobs/report-cronjob.yaml`](k8s/cronjobs/report-cronjob.yaml) |
| NetworkPolicy (allowlist) | [`k8s/network-policies/network-policies.yaml`](k8s/network-policies/network-policies.yaml) |
| Helm Chart | [`helm/ecommerce/`](helm/ecommerce/) |

---

## Manual Step-by-Step Deployment

```bash
# Create cluster
kind create cluster --config kind-config.yaml

# Install NGINX Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Foundation
kubectl apply -f k8s/namespaces/
kubectl apply -f k8s/rbac/
kubectl apply -f k8s/configmaps/

# Stateful workloads
kubectl apply -f k8s/statefulsets/
kubectl get pods -n ecommerce -w   # Watch Redis start

# Application
kubectl apply -f k8s/deployments/
kubectl apply -f k8s/services/
kubectl apply -f k8s/ingress/

# Resilience
kubectl apply -f k8s/hpa/
kubectl apply -f k8s/pdb/
kubectl apply -f k8s/cronjobs/
```

---

## Useful Commands

```bash
# See all pods and which node they're on
kubectl get pods -n ecommerce -o wide

# Follow frontend logs
kubectl logs -f deployment/frontend -n ecommerce

# Watch HPA scale up (load generator drives traffic automatically)
kubectl get hpa -n ecommerce -w

# Resource usage per pod
kubectl top pods -n ecommerce

# Describe a pod (events, probe status, resource limits)
kubectl describe pod <pod-name> -n ecommerce

# Shell into a running pod
kubectl exec -it deployment/frontend -n ecommerce -- sh

# See PersistentVolumes created for Redis
kubectl get pv,pvc -n ecommerce

# Simulate a node drain (tests PDB)
kubectl drain ecommerce-cluster-worker --ignore-daemonsets --delete-emptydir-data
kubectl uncordon ecommerce-cluster-worker

# See full cluster overview
bash scripts/explore.sh
```

---

## Teardown

```bash
# Delete the cluster (removes everything)
bash scripts/teardown.sh

# Or just wipe the namespace (keeps the cluster)
kubectl delete namespace ecommerce
```
