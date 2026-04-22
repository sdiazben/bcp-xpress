#!/usr/bin/env bash
# deploy.sh — reads an app.yaml and creates a Knative Service.
# This is the "cf push" equivalent: descriptor in → running URL out.
set -euo pipefail

DESCRIPTOR="${1:?Usage: ./scripts/deploy.sh <app.yaml>}"

# ── Read descriptor ──
NAME=$(yq '.name' "$DESCRIPTOR")
IMAGE=$(yq '.image' "$DESCRIPTOR")
PORT=$(yq '.port // 8080' "$DESCRIPTOR")
REPLICAS_MIN=$(yq '.replicas.min // 1' "$DESCRIPTOR")
REPLICAS_MAX=$(yq '.replicas.max // 3' "$DESCRIPTOR")

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
  --annotation "bcpxpress.yourco.io/itsi=$(yq '.itsi' "$DESCRIPTOR")" \
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

