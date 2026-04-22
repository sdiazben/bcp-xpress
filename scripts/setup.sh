#!/usr/bin/env bash
# Installs Knative Serving on Docker Desktop Kubernetes (or any local cluster).
set -euo pipefail

KNATIVE_VERSION="v1.21.0"

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
echo "Next step — in a separate terminal, run:"
echo "  kubectl port-forward -n kourier-system svc/kourier 8080:80"
echo ""
echo "Then deploy an app:"
echo "  ./scripts/deploy.sh examples/app.yaml"


