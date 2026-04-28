#!/usr/bin/env bash
# Configures kpack registry credentials and creates a ClusterBuilder.
# Run after setup.sh. Reads credentials from .env or environment variables:
#   REGISTRY_HOST        — e.g. index.docker.io or ghcr.io
#   REGISTRY_USER        — username or bot account
#   REGISTRY_PASSWORD    — password or personal access token
#   REGISTRY_TAG_PREFIX  — e.g. docker.io/myuser (prefix for all built images)
set -euo pipefail

KPACK_VERSION="v0.17.1"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=../.env
  source "$ENV_FILE"
  set +a
fi

: "${REGISTRY_HOST:?Set REGISTRY_HOST (e.g. index.docker.io)}"
: "${REGISTRY_USER:?Set REGISTRY_USER}"

# ── Preflight: ensure kpack CRDs are present ──
if ! kubectl get crd clusterbuilders.kpack.io &>/dev/null; then
  echo "⚠️  kpack CRDs not found. Installing kpack ${KPACK_VERSION}..."
  KPACK_URL="https://github.com/buildpacks-community/kpack/releases/download/${KPACK_VERSION}/release-${KPACK_VERSION#v}.yaml"
  kubectl apply -f "$KPACK_URL" 2>/dev/null || kubectl apply -f "$KPACK_URL"
  echo "⏳ Waiting for kpack controller..."
  kubectl wait --for=condition=Ready pods --all -n kpack --timeout=180s 2>/dev/null || true

  echo "🏗️  Configuring ClusterStore..."
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

  echo "🏗️  Configuring ClusterStack..."
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
fi
: "${REGISTRY_PASSWORD:?Set REGISTRY_PASSWORD}"
: "${REGISTRY_TAG_PREFIX:?Set REGISTRY_TAG_PREFIX (e.g. docker.io/myuser)}"

echo "🔑 Storing registry credentials..."
kubectl create secret docker-registry registry-credentials \
  --docker-server="${REGISTRY_HOST}" \
  --docker-username="${REGISTRY_USER}" \
  --docker-password="${REGISTRY_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "👤 Creating kpack ServiceAccount..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kpack-service-account
  namespace: default
secrets:
- name: registry-credentials
imagePullSecrets:
- name: registry-credentials
EOF

echo ""
echo "🏗️  Creating ClusterBuilder (pulls buildpacks — may take a few minutes)..."
kubectl apply -f - <<EOF
apiVersion: kpack.io/v1alpha2
kind: ClusterBuilder
metadata:
  name: default
spec:
  tag: ${REGISTRY_TAG_PREFIX}/kpack-builder
  serviceAccountRef:
    name: kpack-service-account
    namespace: default
  stack:
    name: base
    kind: ClusterStack
  store:
    name: default
    kind: ClusterStore
  order:
  - group:
    - id: paketo-buildpacks/java
  - group:
    - id: paketo-buildpacks/nodejs
  - group:
    - id: paketo-buildpacks/python
  - group:
    - id: paketo-buildpacks/go
EOF

echo ""
echo "⏳ Waiting for ClusterBuilder to be ready..."
kubectl wait --for=condition=Ready clusterbuilder/default --timeout=300s

echo ""
echo "✅ kpack registry configured!"
echo ""
echo "Deploy an app from source:"
echo "  ./scripts/deploy.sh examples/app-build.yaml"
