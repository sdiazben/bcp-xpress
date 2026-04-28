#!/usr/bin/env bash
# teardown.sh — remove a deployed app, or uninstall ArgoCD entirely.
#   ./scripts/teardown.sh <app-name>   # delete one Application + its manifests
#   ./scripts/teardown.sh --all        # uninstall ArgoCD
set -euo pipefail

TARGET="${1:?Usage: ./scripts/teardown.sh <app-name> | --all}"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ARGOCD_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT=$(git -C "$ARGOCD_DIR" rev-parse --show-toplevel)

if [[ "$TARGET" == "--all" ]]; then
  echo "🧨 Uninstalling ArgoCD..."
  ARGOCD_VERSION="${ARGOCD_VERSION:-v2.13.1}"
  kubectl delete -n argocd \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" \
    --ignore-not-found
  kubectl delete namespace argocd --ignore-not-found
  echo "✅ ArgoCD removed."
  exit 0
fi

NAME="$TARGET"
APP_PATH_REL="argocd/manifests/${NAME}"
APP_PATH_ABS="${REPO_ROOT}/${APP_PATH_REL}"

echo "🗑  Deleting ArgoCD Application '${NAME}'..."
kubectl delete application "$NAME" -n argocd --ignore-not-found

if [[ -d "$APP_PATH_ABS" ]]; then
  echo "🗑  Removing manifests at ${APP_PATH_REL}/..."
  rm -rf "$APP_PATH_ABS"
  git -C "$REPO_ROOT" add "$APP_PATH_REL" 2>/dev/null || true
  if ! git -C "$REPO_ROOT" diff --cached --quiet; then
    git -C "$REPO_ROOT" commit -m "teardown(${NAME}): remove manifests"
    git -C "$REPO_ROOT" push
  fi
fi

echo "✅ ${NAME} torn down."
