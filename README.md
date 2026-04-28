# BCP Xpress POC

> "Here is my app, please run it for me, I do not care how."

A minimal POC that takes an `app.yaml` descriptor and deploys it on Kubernetes — no K8s knowledge required from the developer. Two flavors of the same idea:

- **[knative/](knative/)** — imperative deploy via Knative Serving (the original "cf push" feel)
- **[argocd/](argocd/)** — GitOps deploy via ArgoCD (manifests committed to a Git repo, ArgoCD auto-syncs)

Both share the same `app.yaml` descriptor format.

## Prerequisites

- Docker Desktop with **Kubernetes enabled**
- `kubectl`, `yq` installed (`brew install yq`)
- For knative/: `kn` (`brew install kn`)
- For argocd/: a GitHub repo + Personal Access Token with `repo` scope

## Quick Start — Knative

```bash
cd knative

# 1. Install Knative on your cluster (one-time)
./scripts/setup.sh

# 2. In a separate terminal, expose Knative's gateway
kubectl port-forward -n kourier-system svc/kourier 8080:80

# 3. Deploy an app — the "cf push" moment
./scripts/deploy.sh examples/app.yaml

# 4. Test it
curl -H "Host: hello.default.127.0.0.1.sslip.io" http://localhost:8080/

# 5. Clean up
./scripts/teardown.sh hello
```

See [knative/docs/how-it-works.md](knative/docs/how-it-works.md) for a script-by-script walkthrough.

## Quick Start — ArgoCD

```bash
cd argocd

# 1. Configure GitHub credentials
cp .env.example .env
# Edit .env with your GITHUB_REPO_URL, GITHUB_USER, GITHUB_TOKEN

# 2. Install ArgoCD + register the repo (one-time)
./scripts/setup.sh

# 3. In a separate terminal, expose the ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8081:443

# 4. Deploy an app — renders manifests, commits + pushes, ArgoCD syncs
./scripts/deploy.sh examples/app.yaml

# 5. Test it (port-forward to the Service)
kubectl port-forward svc/hello 8080:80
curl http://localhost:8080/

# 6. Clean up
./scripts/teardown.sh hello
```

## How they compare

| | knative/ | argocd/ |
|---|---|---|
| Source of truth | `kn service create` calls | Git repo |
| Sync trigger | Imperative (developer runs deploy) | ArgoCD polls (3min) or webhook |
| Autoscale | Built-in (Knative scale-to-zero) | Fixed replicas (HPA = future work) |
| Routing | sslip.io URL via Kourier | port-forward to Service |
| Build from source | kpack (via `build:` in app.yaml) | Pre-built images only (v1) |
| Cluster deps | Knative Serving + Kourier + kpack | ArgoCD only |

## Project Structure

```
bcp-xpress/
├── knative/
│   ├── scripts/         # setup, deploy, status, teardown, registry-setup
│   ├── examples/        # app.yaml, app-build.yaml
│   └── docs/            # how-it-works.md
├── argocd/
│   ├── scripts/         # setup, deploy, status, teardown
│   ├── examples/        # app.yaml
│   └── manifests/       # generated K8s YAML (deploy.sh writes here)
└── initial_arch.md      # Full architecture reference
```

## Next Steps

- [ ] CSM/secrets integration
- [ ] Deny-by-default NetworkPolicy from egress declarations
- [ ] Backstage frontend for self-service UI
- [ ] CRD + operator to replace shell scripts
- [ ] Add HPA support to argocd/ flavor
