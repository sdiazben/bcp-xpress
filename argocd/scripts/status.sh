#!/usr/bin/env bash
# status.sh — list ArgoCD Applications and their sync/health status.
set -euo pipefail

if ! kubectl get crd applications.argoproj.io &>/dev/null; then
  echo "❌ ArgoCD not installed. Run ./scripts/setup.sh first."
  exit 1
fi

echo "📋 ArgoCD Applications:"
echo ""
kubectl get applications -n argocd \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REPO:.spec.source.repoURL,PATH:.spec.source.path,REVISION:.status.sync.revision' \
  2>/dev/null || echo "   (no applications yet)"

echo ""
echo "Pods:"
kubectl get pods -l 'app' --all-namespaces 2>/dev/null | grep -v argocd | grep -v kube-system || echo "   (none)"
