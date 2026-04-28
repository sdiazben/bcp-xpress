#!/usr/bin/env bash
# teardown.sh — delete an app or remove the platform entirely.
set -euo pipefail

KNATIVE_VERSION="v1.21.0"
KPACK_VERSION="v0.15.3"

APP="${1:-}"

if [ -z "$APP" ]; then
  echo "Usage:"
  echo "  ./scripts/teardown.sh <app-name>    — delete one app"
  echo "  ./scripts/teardown.sh --all         — remove all apps"
  echo "  ./scripts/teardown.sh --platform    — uninstall Knative + kpack"
  exit 0
fi

if [ "$APP" = "--all" ]; then
  echo "🗑️  Deleting all Knative services..."
  kn service delete --all
  echo "🗑️  Deleting all kpack Images..."
  kubectl delete images.kpack.io --all -n default 2>/dev/null || true
  echo "✅ Done"
elif [ "$APP" = "--platform" ]; then
  echo "🗑️  Removing kpack..."
  kubectl delete -f "https://github.com/buildpacks-community/kpack/releases/download/${KPACK_VERSION}/release-${KPACK_VERSION}.yaml" 2>/dev/null || true
  echo "🗑️  Removing Knative Serving..."
  kubectl delete -f "https://github.com/knative/net-kourier/releases/download/knative-${KNATIVE_VERSION}/kourier.yaml" 2>/dev/null || true
  kubectl delete -f "https://github.com/knative/serving/releases/download/knative-${KNATIVE_VERSION}/serving-core.yaml" 2>/dev/null || true
  kubectl delete -f "https://github.com/knative/serving/releases/download/knative-${KNATIVE_VERSION}/serving-crds.yaml" 2>/dev/null || true
  echo "✅ Platform removed"
elif [ "$APP" = "--knative" ]; then
  echo "⚠️  --knative is deprecated, use --platform to also remove kpack"
  echo "🗑️  Removing Knative Serving..."
  kubectl delete -f "https://github.com/knative/net-kourier/releases/download/knative-${KNATIVE_VERSION}/kourier.yaml" 2>/dev/null || true
  kubectl delete -f "https://github.com/knative/serving/releases/download/knative-${KNATIVE_VERSION}/serving-core.yaml" 2>/dev/null || true
  kubectl delete -f "https://github.com/knative/serving/releases/download/knative-${KNATIVE_VERSION}/serving-crds.yaml" 2>/dev/null || true
  echo "✅ Knative removed"
else
  echo "🗑️  Deleting app: ${APP}"
  kn service delete "$APP" 2>/dev/null || true
  kubectl delete image.kpack.io "$APP" -n default 2>/dev/null || true
  echo "✅ ${APP} deleted"
fi
