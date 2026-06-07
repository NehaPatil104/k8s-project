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
| helm | `winget install Helm.Helm` |

---

## Two Ways to Deploy

| Method | Script | Best for |
|--------|--------|----------|
| **Raw kubectl** | `bash scripts/setup-kind.sh` | Learning each K8s resource individually |
| **Helm** | `bash scripts/setup-helm.sh` | Learning Helm, deploying as a single unit |

Both deploy the exact same app — just different methods.

---

## Option 1 — Raw kubectl (Manual YAML)

```bash
# 1. Create cluster + deploy everything using raw manifests
bash scripts/setup-kind.sh

# 2. Add to hosts file (run Notepad as Administrator on Windows):
#    C:\Windows\System32\drivers\etc\hosts → 127.0.0.1  ecommerce.local

# 3. Open the store:
#    http://ecommerce.local
#    http://localhost:30080   (no hosts file needed)
```

---

## Option 2 — Helm

```bash
# 1. Create the Kind cluster first (only the cluster, no app yet)
kind create cluster --config kind-config.yaml

# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# 2. Deploy everything using Helm (one command!)
cd <path-to>/k8s-project/kind
helm install ecommerce helm/ecommerce

# OR use the automated script which does all of the above
bash scripts/setup-helm.sh
```

### Helm Quick Reference

```bash
# See what's deployed
helm list
helm status ecommerce

# Upgrade — change any value without redeploying everything
helm upgrade ecommerce helm/ecommerce --set frontend.replicas=3
helm upgrade ecommerce helm/ecommerce --set global.imageTag=v0.10.4
helm upgrade ecommerce helm/ecommerce --set loadgenerator.enabled=false

# See rendered YAML without applying
helm template ecommerce helm/ecommerce

# See release history
helm history ecommerce

# Roll back to a previous version
helm rollback ecommerce 1

# Uninstall everything
helm uninstall ecommerce
```

---

## Kubernetes Concepts Map

| Concept | Raw YAML File | Helm Template |
|---------|--------------|---------------|
| Multi-node cluster, Taints | [`kind-config.yaml`](kind-config.yaml) | same |
| Namespaces | [`k8s/namespaces/namespaces.yaml`](k8s/namespaces/namespaces.yaml) | [`helm/ecommerce/templates/namespace.yaml`](helm/ecommerce/templates/namespace.yaml) |
| ResourceQuota | [`k8s/namespaces/resource-quota.yaml`](k8s/namespaces/resource-quota.yaml) | [`helm/ecommerce/templates/namespace.yaml`](helm/ecommerce/templates/namespace.yaml) |
| LimitRange | [`k8s/namespaces/resource-quota.yaml`](k8s/namespaces/resource-quota.yaml) | [`helm/ecommerce/templates/namespace.yaml`](helm/ecommerce/templates/namespace.yaml) |
| ServiceAccounts | [`k8s/rbac/service-accounts.yaml`](k8s/rbac/service-accounts.yaml) | [`helm/ecommerce/templates/rbac.yaml`](helm/ecommerce/templates/rbac.yaml) |
| Roles + RoleBindings | [`k8s/rbac/roles.yaml`](k8s/rbac/roles.yaml) | [`helm/ecommerce/templates/rbac.yaml`](helm/ecommerce/templates/rbac.yaml) |
| StorageClass | [`k8s/storage/storage-class.yaml`](k8s/storage/storage-class.yaml) | — |
| ConfigMap (env vars) | [`k8s/configmaps/services-config.yaml`](k8s/configmaps/services-config.yaml) | values injected via `helm/ecommerce/values.yaml` |
| StatefulSet + PVC | [`k8s/statefulsets/redis-cart.yaml`](k8s/statefulsets/redis-cart.yaml) | [`helm/ecommerce/templates/redis.yaml`](helm/ecommerce/templates/redis.yaml) |
| Tolerations + NodeAffinity | [`k8s/statefulsets/redis-cart.yaml`](k8s/statefulsets/redis-cart.yaml) | [`helm/ecommerce/templates/redis.yaml`](helm/ecommerce/templates/redis.yaml) |
| Deployment + Rolling Update | [`k8s/deployments/frontend.yaml`](k8s/deployments/frontend.yaml) | [`helm/ecommerce/templates/deployments.yaml`](helm/ecommerce/templates/deployments.yaml) |
| Init Containers | [`k8s/deployments/cartservice.yaml`](k8s/deployments/cartservice.yaml) | [`helm/ecommerce/templates/deployments.yaml`](helm/ecommerce/templates/deployments.yaml) |
| Startup / Liveness / Readiness Probes | All deployments | All deployment templates |
| Pod Anti-Affinity | [`k8s/deployments/frontend.yaml`](k8s/deployments/frontend.yaml) | [`helm/ecommerce/templates/deployments.yaml`](helm/ecommerce/templates/deployments.yaml) |
| Downward API | [`k8s/deployments/frontend.yaml`](k8s/deployments/frontend.yaml) | [`helm/ecommerce/templates/deployments.yaml`](helm/ecommerce/templates/deployments.yaml) |
| SecurityContext | All deployments | All deployment templates |
| ClusterIP Service | [`k8s/services/services.yaml`](k8s/services/services.yaml) | [`helm/ecommerce/templates/deployments.yaml`](helm/ecommerce/templates/deployments.yaml) |
| NodePort Service | [`k8s/services/services.yaml`](k8s/services/services.yaml) | [`helm/ecommerce/templates/deployments.yaml`](helm/ecommerce/templates/deployments.yaml) |
| Ingress + routing | [`k8s/ingress/ingress.yaml`](k8s/ingress/ingress.yaml) | [`helm/ecommerce/templates/ingress.yaml`](helm/ecommerce/templates/ingress.yaml) |
| HPA (CPU autoscaling) | [`k8s/hpa/hpa.yaml`](k8s/hpa/hpa.yaml) | [`helm/ecommerce/templates/hpa.yaml`](helm/ecommerce/templates/hpa.yaml) |
| PodDisruptionBudget | [`k8s/pdb/pdb.yaml`](k8s/pdb/pdb.yaml) | [`helm/ecommerce/templates/pdb.yaml`](helm/ecommerce/templates/pdb.yaml) |
| Job | [`k8s/jobs/seed-job.yaml`](k8s/jobs/seed-job.yaml) | — |
| CronJob | [`k8s/cronjobs/report-cronjob.yaml`](k8s/cronjobs/report-cronjob.yaml) | — |
| NetworkPolicy (allowlist) | [`k8s/network-policies/network-policies.yaml`](k8s/network-policies/network-policies.yaml) | — |
| Helm values + templating | — | [`helm/ecommerce/values.yaml`](helm/ecommerce/values.yaml) |
| Helm helpers | — | [`helm/ecommerce/templates/_helpers.tpl`](helm/ecommerce/templates/_helpers.tpl) |

---

## Manual kubectl Step-by-Step

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

## Useful kubectl Commands

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

## Helm Chart Structure

```
helm/ecommerce/
├── Chart.yaml          # Chart metadata (name, version, description)
├── values.yaml         # All configurable values — the single source of truth
└── templates/
    ├── _helpers.tpl    # Reusable template functions
    ├── namespace.yaml  # Namespace + ResourceQuota + LimitRange
    ├── rbac.yaml       # ServiceAccount + Role + RoleBinding
    ├── deployments.yaml # All 11 service Deployments + Services
    ├── redis.yaml      # Redis StatefulSet + Service
    ├── ingress.yaml    # Ingress
    ├── hpa.yaml        # HorizontalPodAutoscalers
    └── pdb.yaml        # PodDisruptionBudgets
```

---

## Teardown

```bash
# Helm teardown
helm uninstall ecommerce

# Raw kubectl teardown
bash scripts/teardown.sh

# Or just wipe the namespace (keeps the cluster)
kubectl delete namespace ecommerce

# Delete the Kind cluster entirely
kind delete cluster --name ecommerce-cluster
```
