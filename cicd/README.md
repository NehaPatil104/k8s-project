# CI/CD Setup — GitHub Actions + ArgoCD

GitOps-based CI/CD pipeline for the Online Boutique + Reviews Service.

---

## Architecture

```
Developer pushes code
        │
        ▼
┌───────────────────┐
│  GitHub Actions   │  CI Pipeline (.github/workflows/ci.yaml)
│                   │  1. Run tests (jest)
│                   │  2. Build Docker image
│                   │  3. Push to Docker Hub
│                   │  4. Update imageTag in values.yaml
│                   │  5. Commit + push to git
└────────┬──────────┘
         │ git push (values.yaml updated)
         ▼
┌───────────────────┐
│     ArgoCD        │  CD (GitOps)
│                   │  Watches git repo every 3 min
│                   │  Detects new imageTag in values.yaml
│                   │  Runs: helm upgrade ecommerce
│                   │  K8s does rolling update
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│   Kind Cluster    │
│   (or EKS)        │  New version live — zero downtime
└───────────────────┘
```

---

## Components

### GitHub Actions Workflows

| Workflow | File | Triggers | Does |
|----------|------|----------|------|
| CI | `.github/workflows/ci.yaml` | Push to `reviews-service/**` | Test → Build → Push → Update tag |
| CD | `.github/workflows/cd.yaml` | Push to `kind/helm/**` | Lint → Validate → Security scan |

### ArgoCD Application

| File | Purpose |
|------|---------|
| `argocd/install.sh` | Installs ArgoCD on Kind cluster |
| `argocd/application.yaml` | Registers the ecommerce app in ArgoCD |

---

## Setup Guide

### Step 1 — Add GitHub Secrets

Go to: `GitHub repo → Settings → Secrets and variables → Actions → New repository secret`

| Secret Name | Value |
|-------------|-------|
| `DOCKERHUB_USERNAME` | `NehaPatil104` |
| `DOCKERHUB_TOKEN` | Your Docker Hub access token |

**Create Docker Hub token:**
1. Login to hub.docker.com
2. Account Settings → Security → New Access Token
3. Name it `github-actions`, copy the token
4. Paste as `DOCKERHUB_TOKEN` in GitHub secrets

---

### Step 2 — Install ArgoCD on Kind

```bash
# Make sure Kind cluster is running
kubectl get nodes

# Install ArgoCD
bash cicd/argocd/install.sh
```

ArgoCD UI will be at: `https://localhost:8080`

---

### Step 3 — Push Code and Watch CI Run

```bash
# Make a change to reviews-service
echo "// updated" >> reviews-service/src/index.js

# Commit and push
git add .
git commit -m "feat(reviews-service): trigger ci pipeline demo"
git push origin main
```

Then watch:
1. **GitHub** → Actions tab → CI pipeline running
2. **GitHub** → After CI: `values.yaml` gets a new commit with updated tag
3. **ArgoCD UI** → App goes `OutOfSync` → then `Syncing` → then `Synced`
4. **kubectl** → `kubectl get pods -n ecommerce -w` → rolling update

---

## The Full Flow Step by Step

```
1. You push code to reviews-service/
   git push origin main

2. GitHub Actions CI starts automatically
   ├── Installs Node.js dependencies
   ├── Runs jest tests
   ├── Fails here if tests fail ← safety gate
   ├── Builds Docker image
   │   nehapatil104/reviews-service:abc1234
   ├── Pushes to Docker Hub
   └── Updates kind/helm/ecommerce/values.yaml:
       reviewsService:
         imageTag: "abc1234"   ← was "latest"

3. GitHub Actions commits values.yaml back to git
   commit: "ci(helm): update reviews-service image tag to abc1234"

4. ArgoCD detects the git change (polls every 3 min)
   ├── Sees reviewsService.imageTag changed
   ├── Runs: helm template → compares with cluster state
   └── Detects drift → triggers sync

5. ArgoCD syncs
   ├── helm upgrade ecommerce kind/helm/ecommerce
   └── K8s performs rolling update:
       Old pods stay up while new ones start
       New pods pass readiness probe
       Traffic switches to new pods
       Old pods terminated

6. New version is live — zero downtime ✓
```

---

## ArgoCD Key Concepts

| Concept | Meaning |
|---------|---------|
| **Application** | An ArgoCD resource that maps a git path to a K8s namespace |
| **Sync** | ArgoCD applying git state to the cluster |
| **OutOfSync** | Git state differs from cluster state |
| **Self-heal** | ArgoCD reverts manual kubectl changes to match git |
| **Prune** | ArgoCD deletes K8s resources removed from git |
| **GitOps** | Git is the single source of truth for cluster state |

---

## Useful Commands

```bash
# Watch CI pipeline
# Go to: https://github.com/NehaPatil104/k8s-project/actions

# ArgoCD port-forward (if not running)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Check ArgoCD app status
kubectl get application -n argocd

# Force immediate ArgoCD sync (without waiting 3 min)
kubectl patch application ecommerce -n argocd \
  --type merge -p '{"operation":{"sync":{}}}'

# Watch rolling update after ArgoCD syncs
kubectl get pods -n ecommerce -w

# Check which image tag is running
kubectl get deployment reviews-service -n ecommerce \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```
