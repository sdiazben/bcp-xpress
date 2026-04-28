#!/usr/bin/env bash
# Installs ArgoCD on Docker Desktop Kubernetes and registers a GitHub repo for GitOps sync.
set -euo pipefail

ARGOCD_VERSION="v2.13.1"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=../.env
  source "$ENV_FILE"
  set +a
fi

: "${GITHUB_REPO_URL:?Set GITHUB_REPO_URL in argocd/.env (e.g. https://github.com/sdiazben/bcp-xpress.git)}"
: "${GITHUB_USER:?Set GITHUB_USER in argocd/.env}"
: "${GITHUB_TOKEN:?Set GITHUB_TOKEN in argocd/.env (PAT with repo scope)}"

echo "🔍 Checking cluster..."
kubectl get nodes >/dev/null || { echo "❌ No cluster found. Enable Kubernetes in Docker Desktop."; exit 1; }

echo ""
echo "📦 Installing ArgoCD ${ARGOCD_VERSION}..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo ""
echo "⏳ Waiting for ArgoCD pods..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s 2>/dev/null || true

echo ""
echo "🔑 Registering GitHub repo with ArgoCD..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: bcp-xpress-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: ${GITHUB_REPO_URL}
  username: ${GITHUB_USER}
  password: ${GITHUB_TOKEN}
EOF

echo ""
echo "🔐 Fetching initial admin password..."
ADMIN_PASS=$(kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "<not yet generated — try again in 30s>")

echo ""
echo "✅ ArgoCD ready!"
echo ""
echo "ArgoCD UI:"
echo "  1. In a separate terminal:"
echo "       kubectl port-forward -n argocd svc/argocd-server 8081:443"
echo "  2. Open https://localhost:8081 (accept self-signed cert)"
echo "  3. Login: admin / ${ADMIN_PASS}"
echo ""
echo "Deploy an app:"
echo "  ./scripts/deploy.sh examples/app.yaml"
