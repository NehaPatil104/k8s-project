# Kubernetes Learning Project — Online Boutique (Kind)

Production-style K8s manifests wrapping Google's [Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) microservices demo.
All K8s YAML is written from scratch to cover the full breadth of Kubernetes concepts.

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
                                        |
                                  [loadgenerator]
```

11 real microservices (Go, Python, Node.js, Java, C#) communicating over **gRPC**.

---

## Project Structure

```
kind/
├── kind-config.yaml              # Kind cluster definition (1 control-plane + 3 workers)
├── k8s/                          # Raw Kubernetes manifests (Option 1)
│   ├── namespaces/               # Namespace, ResourceQuota, LimitRange
│   ├── rbac/                     # ServiceAccounts, Roles, RoleBindings
│   ├── configmaps/               # App configuration (env vars)
│   ├── secrets/                  # Sensitive data
│   ├── storage/                  # StorageClass
│   ├── statefulsets/             # Redis (StatefulSet + PVC)
│   ├── deployments/              # All 11 service Deployments
│   ├── services/                 # ClusterIP + NodePort Services
│   ├── ingress/                  # NGINX Ingress routing rules
│   ├── hpa/                      # HorizontalPodAutoscalers
│   ├── pdb/                      # PodDisruptionBudgets
│   ├── jobs/                     # One-time smoke test Job
│   ├── cronjobs/                 # Scheduled health check + cleanup
│   └── network-policies/         # Zero-trust NetworkPolicies
├── helm/                         # Helm chart (Option 2)
│   └── ecommerce/
│       ├── Chart.yaml            # Chart metadata
│       ├── values.yaml           # All configurable values
│       └── templates/            # Templated K8s manifests
└── scripts/
    ├── setup-kind.sh             # Automated setup using raw kubectl
    ├── setup-helm.sh             # Automated setup using Helm
    ├── explore.sh                # Cluster overview commands
    └── teardown.sh               # Delete the cluster
```

---

## Prerequisites

| Tool | Install | Purpose |
|------|---------|---------|
| Docker Desktop | https://www.docker.com/products/docker-desktop | Runs Kind nodes as containers |
| kind | `winget install Kubernetes.kind` | Creates local K8s cluster |
| kubectl | `winget install Kubernetes.kubectl` | Talks to the cluster |
| helm | `winget install Helm.Helm` | Package manager for K8s |
| k9s *(optional)* | `winget install k9s` | Terminal UI for cluster visualization |

---

## Two Ways to Deploy

| Method | Script | Best for |
|--------|--------|----------|
| **Raw kubectl** | `bash scripts/setup-kind.sh` | Learning each K8s resource individually |
| **Helm** | `bash scripts/setup-helm.sh` | Learning Helm, deploying as a single packaged unit |

Both deploy the exact same app — just different methods.

---

## Option 1 — Raw kubectl

```bash
# Deploy everything using raw manifests
bash scripts/setup-kind.sh
```

What the script does:
1. Creates the Kind cluster from `kind-config.yaml`
2. Installs NGINX Ingress Controller + patches nodeSelector to control-plane
3. Installs Metrics Server (needed for HPA)
4. Applies all manifests in order (namespaces → rbac → config → statefulsets → deployments → services → ingress → hpa → pdb → cronjobs)
5. Runs a smoke test Job
6. Prints the access URL

---

## Option 2 — Helm

```bash
# Deploy everything using the Helm chart
bash scripts/setup-helm.sh
```

What the script does:
1. Creates the Kind cluster from `kind-config.yaml`
2. Installs NGINX Ingress Controller + patches nodeSelector to control-plane
3. Runs `helm lint` to validate the chart
4. Runs `helm install ecommerce helm/ecommerce`
5. Waits for all pods to be ready
6. Prints access URL + useful Helm commands

### Helm Quick Reference

```bash
# See what's installed
helm list
helm status ecommerce

# See rendered YAML without applying anything
helm template ecommerce helm/ecommerce

# Upgrade — change values without full redeploy
helm upgrade ecommerce helm/ecommerce --set frontend.replicas=3
helm upgrade ecommerce helm/ecommerce --set global.imageTag=v0.10.4
helm upgrade ecommerce helm/ecommerce --set loadgenerator.enabled=false

# See release history
helm history ecommerce

# Roll back to a previous revision
helm rollback ecommerce 1

# Uninstall everything
helm uninstall ecommerce
```

---

## Accessing the App

After either setup script completes:

```
# 1. Add to hosts file (run Notepad as Administrator on Windows)
#    File: C:\Windows\System32\drivers\etc\hosts
#    Add:  127.0.0.1  ecommerce.local

# 2. Open in browser
http://ecommerce.local          ← requires hosts file entry
http://localhost:30080          ← NodePort, no hosts file needed
```

---

## Important: Ingress on Kind

The NGINX Ingress controller **must run on the control-plane node** because that is the only node with Docker port 80 mapped to the host machine.

```
Browser → localhost:80
              ↓  (Docker port mapping — only on control-plane)
         control-plane container port 80
              ↓  (NGINX must be HERE)
         NGINX Ingress → frontend service → frontend pods
```

The Kind ingress manifest's nodeSelector only has `kubernetes.io/os=linux` — it does NOT pin to control-plane by default. Both setup scripts patch this automatically:

```bash
kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"ingress-ready":"true","kubernetes.io/os":"linux"}}]'
```

If you ever reinstall the ingress controller manually, always apply this patch afterwards.

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
| ConfigMap (env vars) | [`k8s/configmaps/services-config.yaml`](k8s/configmaps/services-config.yaml) | values injected via [`helm/ecommerce/values.yaml`](helm/ecommerce/values.yaml) |
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
| Helm named templates | — | [`helm/ecommerce/templates/_helpers.tpl`](helm/ecommerce/templates/_helpers.tpl) |

---

## Helm Chart Structure

```
helm/ecommerce/
├── Chart.yaml           # Chart metadata (name, version, description)
├── values.yaml          # All configurable values — the single source of truth
└── templates/
    ├── _helpers.tpl     # Reusable named templates (labels, image path)
    ├── namespace.yaml   # Namespace + ResourceQuota + LimitRange
    ├── rbac.yaml        # ServiceAccount + Role + RoleBinding
    ├── deployments.yaml # All 11 service Deployments + ClusterIP Services
    ├── redis.yaml       # Redis StatefulSet + Service
    ├── ingress.yaml     # NGINX Ingress routing rules
    ├── hpa.yaml         # HorizontalPodAutoscalers
    └── pdb.yaml         # PodDisruptionBudgets
```

---

## Useful kubectl Commands

```bash
# See all pods and which node they're on
kubectl get pods -n ecommerce -o wide

# Watch pods start up
kubectl get pods -n ecommerce -w

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

# Check ingress controller is on control-plane
kubectl get pods -n ingress-nginx -o wide

# Simulate a node drain (tests PDB)
kubectl drain ecommerce-cluster-worker --ignore-daemonsets --delete-emptydir-data
kubectl uncordon ecommerce-cluster-worker

# Full cluster overview
bash scripts/explore.sh
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `ERR_EMPTY_RESPONSE` on ecommerce.local | Ingress controller on wrong node | Patch nodeSelector (see Ingress section above) |
| `ImagePullBackOff` | Network can't reach registry | Check internet, retry `kubectl delete pod` |
| `FailedCreate` on pods | LimitRange violation | Check `kubectl describe replicaset` for min/max errors |
| `cluster unreachable` in Helm/kubectl | Wrong kubectl context | `kubectl config use-context kind-ecommerce-cluster` |
| Helm release already exists | Previous install not cleaned | `helm uninstall ecommerce -n default` |
| Pods stuck in `Pending` | Node taint not tolerated | Check tolerations in pod spec |

---

## Teardown

```bash
# Helm teardown (removes all K8s resources created by Helm)
helm uninstall ecommerce

# Raw kubectl teardown
bash scripts/teardown.sh

# Delete just the namespace (keeps the cluster running)
kubectl delete namespace ecommerce

# Delete the Kind cluster entirely (removes everything)
kind delete cluster --name ecommerce-cluster
```

---

## Known Issues & Fixes Applied

| Issue | Fix |
|-------|-----|
| NGINX ingress controller lands on worker node instead of control-plane | Both setup scripts patch the Deployment nodeSelector to require `ingress-ready=true` |
| `SHOPPING_ASSISTANT_SERVICE_ADDR` not set — frontend panics | Added to `values.yaml` and `configmaps/services-config.yaml` |
| Init containers below LimitRange minimum (10m CPU / 16Mi RAM) | Lowered LimitRange `min` and raised init container requests |
| Helm release deployed to `default` namespace instead of `ecommerce` | Namespace is created inside the Helm chart templates |
