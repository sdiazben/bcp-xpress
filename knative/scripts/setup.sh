#!/usr/bin/env bash
# Installs Knative Serving + kpack on Docker Desktop Kubernetes (or any local cluster).
set -euo pipefail

KNATIVE_VERSION="v1.21.0"
KPACK_VERSION="v0.17.1"

echo "🔍 Checking cluster..."
kubectl get nodes || { echo "❌ No cluster found. Enable Kubernetes in Docker Desktop."; exit 1; }

echo ""
echo "📦 Installing Knative Serving CRDs..."
kubectl apply -f "https://github.com/knative/serving/releases/download/knative-${KNATIVE_VERSION}/serving-crds.yaml"

echo ""
echo "📦 Installing Knative Serving core..."
kubectl apply -f "https://github.com/knative/serving/releases/download/knative-${KNATIVE_VERSION}/serving-core.yaml"

echo ""
echo "🌐 Installing Kourier networking..."
kubectl apply -f "https://github.com/knative/net-kourier/releases/download/knative-${KNATIVE_VERSION}/kourier.yaml"

echo ""
echo "⚙️  Configuring networking..."
kubectl patch configmap/config-network \
  -n knative-serving \
  --type merge \
  -p '{"data":{"ingress-class":"kourier.ingress.networking.knative.dev"}}'

# Use sslip.io so Knative URLs resolve to localhost
kubectl patch configmap/config-domain \
  -n knative-serving \
  --type merge \
  -p '{"data":{"127.0.0.1.sslip.io":""}}'

echo ""
echo "⏳ Waiting for pods..."
kubectl wait --for=condition=Ready pods --all -n knative-serving --timeout=180s 2>/dev/null || true

echo ""
echo "✅ Knative Serving is ready!"

echo ""
echo "📦 Installing kpack..."
KPACK_URL="https://github.com/buildpacks-community/kpack/releases/download/${KPACK_VERSION}/release-${KPACK_VERSION#v}.yaml"
# Apply twice: first pass creates CRDs, second pass creates resources that depend on them
kubectl apply -f "$KPACK_URL" 2>/dev/null || kubectl apply -f "$KPACK_URL"

echo ""
echo "⏳ Waiting for kpack controller..."
kubectl wait --for=condition=Ready pods --all -n kpack --timeout=180s 2>/dev/null || true

echo ""
echo "🏗️  Configuring kpack ClusterStore (Paketo buildpacks)..."
kubectl apply -f - <<'EOF'
apiVersion: kpack.io/v1alpha2
kind: ClusterStore
metadata:
  name: default
spec:
  sources:
  - image: paketobuildpacks/java
  - image: paketobuildpacks/nodejs
  - image: paketobuildpacks/python
  - image: paketobuildpacks/go
EOF

echo ""
echo "🏗️  Configuring kpack ClusterStack (Paketo Jammy base)..."
kubectl apply -f - <<'EOF'
apiVersion: kpack.io/v1alpha2
kind: ClusterStack
metadata:
  name: base
spec:
  id: "io.buildpacks.stacks.jammy"
  buildImage:
    image: paketobuildpacks/build-jammy-base
  runImage:
    image: paketobuildpacks/run-jammy-base
EOF

echo ""
echo "✅ Platform ready!"
echo ""
echo "Next steps:"
echo "  1. Configure registry credentials (required for kpack builds):"
echo "       REGISTRY_HOST=index.docker.io \\"
echo "       REGISTRY_USER=myuser \\"
echo "       REGISTRY_PASSWORD=mytoken \\"
echo "       REGISTRY_TAG_PREFIX=docker.io/myuser \\"
echo "       ./scripts/registry-setup.sh"
echo ""
echo "  2. In a separate terminal, start the ingress proxy:"
echo "       kubectl port-forward -n kourier-system svc/kourier 8080:80"
echo ""
echo "  3. Deploy an app:"
echo "       ./scripts/deploy.sh examples/app.yaml          # pre-built image"
echo "       ./scripts/deploy.sh examples/app-build.yaml    # build from source"


