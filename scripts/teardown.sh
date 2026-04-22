#!/usr/bin/env bash
# teardown.sh — delete an app or remove Knative entirely.
set -euo pipefail

APP="${1:-}"

if [ -z "$APP" ]; then
  echo "Usage:"
  echo "  ./scripts/teardown.sh <app-name>    — delete one app"
  echo "  ./scripts/teardown.sh --all         — remove all apps"
  echo "  ./scripts/teardown.sh --knative     — uninstall Knative"
  exit 0
fi

if [ "$APP" = "--all" ]; then
  echo "🗑️  Deleting all Knative services..."
  kn service delete --all
  echo "✅ Done"
elif [ "$APP" = "--knative" ]; then
  echo "🗑️  Removing Knative Serving..."
  kubectl delete -f "https://github.com/knative/net-kourier/releases/download/knative-v1.21.0/kourier.yaml" 2>/dev/null || true
  kubectl delete -f "https://github.com/knative/serving/releases/download/knative-v1.21.0/serving-core.yaml" 2>/dev/null || true
  kubectl delete -f "https://github.com/knative/serving/releases/download/knative-v1.21.0/serving-crds.yaml" 2>/dev/null || true
  echo "✅ Knative removed"
else
  echo "🗑️  Deleting app: ${APP}"
  kn service delete "$APP"
  echo "✅ ${APP} deleted"
fi


