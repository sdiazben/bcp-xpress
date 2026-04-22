# BCP Xpress POC

> "Here is my app, please run it for me, I do not care how."

A minimal POC that takes an `app.yaml` descriptor and deploys it on Kubernetes via **Knative Serving** — no K8s knowledge required from the developer.

## Prerequisites

- Docker Desktop with **Kubernetes enabled**
- `kubectl`, `kn`, `yq` installed (`brew install kn yq`)

## Quick Start

```bash
# 1. Install Knative on your cluster (one-time)
./scripts/setup.sh

# 2. In a separate terminal, expose Knative's gateway
kubectl port-forward -n kourier-system svc/kourier 8080:80

# 3. Deploy an app — this is the "cf push" moment
./scripts/deploy.sh examples/app.yaml

# 4. Test it
curl -H "Host: my-service.default.127.0.0.1.sslip.io" http://localhost:8080/

# 5. Check status
./scripts/status.sh
./scripts/status.sh my-service

# 6. Clean up
./scripts/teardown.sh my-service
```

## What Happens Under the Hood

```
Developer: app.yaml          You are here (POC)
       │                            │
       ▼                            ▼
  deploy.sh reads YAML  ──→  kn service create
                                    │
                              Knative Serving
                              ├── Creates Deployment
                              ├── Creates Service + Route
                              ├── Autoscales 0-to-N
                              └── Manages revisions
```

The developer never sees Deployments, Services, Ingress, HPA, or PodDisruptionBudgets. Knative handles all of it.

## Docs

- [How it works](docs/how-it-works.md) — logic walkthrough of every script and what Knative does under the hood

## Project Structure

```
bcp-xpress/
├── examples/app.yaml       # The ONLY file a developer maintains
├── scripts/
│   ├── setup.sh            # Install Knative on Docker Desktop K8s
│   ├── deploy.sh           # app.yaml → Knative Service
│   ├── status.sh           # Show app status / revisions
│   └── teardown.sh         # Delete apps or remove Knative
└── initial_arch.md         # Full architecture reference
```

## Next Steps

- [ ] Add kpack for source-to-image builds (JAR → container image)
- [ ] Add CSM/secrets integration
- [ ] Add deny-by-default NetworkPolicy from egress declarations
- [ ] Add Backstage frontend for self-service UI
- [ ] Build CRD + operator to replace shell scripts


