#!/usr/bin/env bash
# deploy.sh — reads an app.yaml and creates a Knative Service.
# Supports pre-built images (image:) or kpack builds (build:).
set -euo pipefail

DESCRIPTOR="${1:?Usage: ./scripts/deploy.sh <app.yaml>}"

# ── Read descriptor ──
NAME=$(yq '.name' "$DESCRIPTOR")
PORT=$(yq '.port // 8080' "$DESCRIPTOR")
REPLICAS_MIN=$(yq '.replicas.min // 1' "$DESCRIPTOR")
REPLICAS_MAX=$(yq '.replicas.max // 3' "$DESCRIPTOR")
ITSI=$(yq '.itsi' "$DESCRIPTOR")

# ── Determine image source ──
BUILD_SOURCE=$(yq '.build.source // ""' "$DESCRIPTOR")
IMAGE=$(yq '.image // ""' "$DESCRIPTOR")

if [[ -n "$BUILD_SOURCE" ]]; then
  BUILD_TAG=$(yq '.build.tag' "$DESCRIPTOR")
  DESCRIPTOR_DIR=$(dirname "$(realpath "$DESCRIPTOR")")

  echo "🏗️  Building ${NAME} with kpack..."
  echo "   source: ${BUILD_SOURCE}"
  echo "   tag:    ${BUILD_TAG}"
  echo ""

  if [[ "$BUILD_SOURCE" == http* || "$BUILD_SOURCE" == git@* ]]; then
    # Git source — apply kpack Image resource directly
    GIT_REVISION=$(yq '.build.revision // "main"' "$DESCRIPTOR")
    kubectl apply -f - <<EOF
apiVersion: kpack.io/v1alpha2
kind: Image
metadata:
  name: ${NAME}
  namespace: default
spec:
  tag: ${BUILD_TAG}
  serviceAccountName: kpack-service-account
  builder:
    name: default
    kind: ClusterBuilder
  source:
    git:
      url: ${BUILD_SOURCE}
      revision: ${GIT_REVISION}
EOF
  else
    # Local path — use kp CLI to package and upload source
    if ! command -v kp &>/dev/null; then
      echo "❌ 'kp' CLI is required for local path builds."
      echo "   Install: brew tap buildpacks-community/tap && brew install buildpacks-community/tap/kp"
      exit 1
    fi
    SOURCE_PATH="${DESCRIPTOR_DIR}/${BUILD_SOURCE}"
    kp image save "$NAME" \
      --tag "$BUILD_TAG" \
      --local-path "$(realpath "$SOURCE_PATH")" \
      --cluster-builder default \
      --namespace default
  fi

  echo "⏳ Waiting for kpack build to complete..."
  echo "   (follow logs: kubectl logs -n kpack -l build.kpack.io/image=${NAME} --follow)"
  echo ""

  TIMEOUT=600
  ELAPSED=0
  while true; do
    STATUS=$(kubectl get image "$NAME" -n default \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    if [[ "$STATUS" == "True" ]]; then
      break
    elif [[ "$STATUS" == "False" ]]; then
      MSG=$(kubectl get image "$NAME" -n default \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null || echo "unknown")
      echo "❌ Build failed: ${MSG}"
      exit 1
    fi
    if [[ $ELAPSED -ge $TIMEOUT ]]; then
      echo "❌ Build timed out after ${TIMEOUT}s"
      exit 1
    fi
    sleep 10
    ELAPSED=$((ELAPSED + 10))
  done

  IMAGE=$(kubectl get image "$NAME" -n default -o jsonpath='{.status.latestImage}')
  echo "✅ Build complete: ${IMAGE}"
  echo ""

elif [[ -z "$IMAGE" ]]; then
  echo "❌ app.yaml must specify either 'image' or 'build'"
  exit 1
fi

echo "🚀 Deploying ${NAME}..."
echo "   image:    ${IMAGE}"
echo "   port:     ${PORT}"
echo "   replicas: ${REPLICAS_MIN}-${REPLICAS_MAX}"

# ── Build env var args ──
ENV_ARGS=""
ENV_COUNT=$(yq '.env | length // 0' "$DESCRIPTOR")
for ((i=0; i<ENV_COUNT; i++)); do
  KEY=$(yq ".env[$i].name" "$DESCRIPTOR")
  VAL=$(yq ".env[$i].value" "$DESCRIPTOR")
  ENV_ARGS="${ENV_ARGS} --env ${KEY}=${VAL}"
done

# ── Deploy via kn CLI ──
kn service create "$NAME" \
  --image "$IMAGE" \
  --port "$PORT" \
  --scale-min "$REPLICAS_MIN" \
  --scale-max "$REPLICAS_MAX" \
  --annotation "bcpxpress.yourco.io/itsi=${ITSI}" \
  $ENV_ARGS \
  --force \
  2>&1

echo ""
echo "✅ ${NAME} deployed!"
echo ""
URL=$(kn service describe "$NAME" -o url)
echo "URL: ${URL}"
echo ""
echo "Test it (with port-forward running):"
echo "  curl -H 'Host: ${URL#http://}' http://localhost:8080/"
