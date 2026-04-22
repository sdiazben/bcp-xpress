# How It Works — BCP Xpress POC

## The Big Picture

The POC has **two layers**:
1. **Your layer** — 4 shell scripts that read `app.yaml` and talk to Kubernetes
2. **Knative's layer** — runs inside Kubernetes and manages everything a developer would normally have to configure

```
Developer
   │
   │  writes app.yaml (18 lines)
   ▼
deploy.sh  ──reads YAML──→  kn CLI  ──creates──→  Knative Serving
                                                        │
                                           ┌────────────┴────────────┐
                                           │ Kubernetes resources     │
                                           │ created automatically:   │
                                           │  - Deployment            │
                                           │  - Service               │
                                           │  - Ingress/Route         │
                                           │  - HPA (autoscaling)     │
                                           │  - Revision tracking     │
                                           └─────────────────────────┘
```

---

## `setup.sh` — One-Time Platform Install

This installs **3 things** into your Kubernetes cluster:

```
Knative CRDs       → Teaches Kubernetes what a "Knative Service" is
                     (new resource types: Service, Route, Revision, Configuration)

Knative Core       → The controller that watches those resources
                     and creates Deployments/HPAs/etc from them

Kourier            → A lightweight HTTP gateway/proxy
                     (receives traffic and routes to the right app)
```

Then it patches two `ConfigMap`s:

- **`config-network`** → tells Knative to use Kourier as the router
- **`config-domain`** → tells Knative to generate URLs like `my-service.default.127.0.0.1.sslip.io`
  - `sslip.io` is a public DNS trick: any `*.127.0.0.1.sslip.io` resolves to `127.0.0.1` — so your local machine can reach it without touching `/etc/hosts`

---

## `deploy.sh` — The "cf push" Moment

This is the core of the POC. Step by step:

**Step 1 — Read the app.yaml** using `yq` (a YAML parser):
```bash
NAME=$(yq '.name' app.yaml)         # → "my-service"
IMAGE=$(yq '.image' app.yaml)       # → "docker.io/kennethreitz/httpbin"
PORT=$(yq '.port // 8080' app.yaml) # → 8080 (or default if missing)
```

**Step 2 — Build env var flags** by looping over the `env` array:
```bash
# app.yaml has: env: [{name: LOG_LEVEL, value: info}]
# This becomes: --env LOG_LEVEL=info
```

**Step 3 — Call `kn service create`** with all the values:
```bash
kn service create my-service \
  --image docker.io/kennethreitz/httpbin \
  --port 8080 \
  --scale-min 1 --scale-max 3 \
  --env LOG_LEVEL=info \
  --force   # ← "update if already exists"
```

The `kn` CLI translates this into a **Knative Service** resource and applies it to Kubernetes. Knative's controller then generates the full K8s resource graph automatically.

**Step 4 — Print the URL** so the developer knows where their app is.

---

## `status.sh` — Observability

Uses `kn` to show what Knative knows about an app:

- `kn service list` → all apps, their URLs, ready status
- `kn service describe <name>` → full details of one app
- `kn revision list --service <name>` → **every deployment is a revision** — this is where Knative shines. Every `deploy.sh` run creates a new revision, and Knative can split traffic between them (canary deployments for free)

---

## `teardown.sh` — Lifecycle Management

Three modes:

| Command | What it does |
|---|---|
| `teardown.sh my-service` | Deletes one Knative Service and all its K8s resources |
| `teardown.sh --all` | Deletes all deployed apps |
| `teardown.sh --knative` | Uninstalls Knative itself from the cluster |

---

## What Knative Actually Does For You

This is the key insight — what Knative generates from a single `kn service create`:

| Kubernetes resource | What it does | Without Knative |
|---|---|---|
| `Deployment` | Runs your pods | Must write by hand |
| `Service` | Internal DNS for your app | Must write by hand |
| `Ingress/Route` | Exposes it externally | Must write by hand |
| `HPA` | Autoscaling rules | Must write by hand |
| `Revision` | Snapshot of every deploy | No equivalent |
| `PodDisruptionBudget` | Safe rolling upgrades | Must write by hand |

The developer wrote **18 lines of YAML**. Without this platform they'd write ~150+ lines across 5+ files.

---

## What's Missing (Next Steps)

| Gap | What fills it |
|---|---|
| Developer gives a JAR, not an image | **kpack** — builds OCI image from JAR automatically |
| Secrets from CyberArk | **External Secrets Operator** |
| Network deny-by-default | **NetworkPolicy** generated from `egress:` block |
| GUI instead of CLI | **Backstage** portal |
| Replace shell scripts with real automation | **Custom K8s Operator + CRD** |

