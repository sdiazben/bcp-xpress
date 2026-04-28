#!/usr/bin/env bash
# status.sh — show status of all deployed apps or a specific one.
set -euo pipefail

APP="${1:-}"

if [ -z "$APP" ]; then
  echo "📋 All BCP Xpress apps:"
  echo ""
  kn service list
  echo ""
  echo "📦 kpack builds:"
  kubectl get images.kpack.io -n default 2>/dev/null || echo "   (none)"
else
  echo "📋 App: ${APP}"
  echo ""
  kn service describe "$APP"
  echo ""
  echo "📊 Revisions:"
  kn revision list --service "$APP"

  if kubectl get image.kpack.io "$APP" -n default &>/dev/null; then
    echo ""
    echo "🏗️  kpack build status:"
    kubectl get image.kpack.io "$APP" -n default \
      -o custom-columns="READY:.status.conditions[?(@.type=='Ready')].status,LATEST-IMAGE:.status.latestImage,REASON:.status.conditions[?(@.type=='Ready')].message"
    echo ""
    echo "   Recent builds:"
    kubectl get builds.kpack.io -n default \
      -l "image.kpack.io/image=${APP}" \
      --sort-by='.metadata.creationTimestamp' 2>/dev/null || true
  fi
fi
