#!/usr/bin/env bash
# deploy.sh — reads an app.yaml, renders K8s manifests into argocd/manifests/<name>/,
# commits + pushes to the GitHub repo, then creates/updates an ArgoCD Application.
set -euo pipefail

DESCRIPTOR="${1:?Usage: ./scripts/deploy.sh <app.yaml>}"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ARGOCD_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT=$(git -C "$ARGOCD_DIR" rev-parse --show-toplevel)
ENV_FILE="${ARGOCD_DIR}/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=../.env
  source "$ENV_FILE"
  set +a
fi

: "${GITHUB_REPO_URL:?Set GITHUB_REPO_URL in argocd/.env}"

# ── Read descriptor ──
NAME=$(yq '.name' "$DESCRIPTOR")
IMAGE=$(yq '.image' "$DESCRIPTOR")
PORT=$(yq '.port // 8080' "$DESCRIPTOR")
REPLICAS=$(yq '.replicas.min // 1' "$DESCRIPTOR")
ITSI=$(yq '.itsi' "$DESCRIPTOR")

if [[ -z "$IMAGE" || "$IMAGE" == "null" ]]; then
  echo "❌ app.yaml must specify 'image'"
  exit 1
fi

# ── Path inside the repo where ArgoCD will read manifests ──
APP_PATH_REL="argocd/manifests/${NAME}"
APP_PATH_ABS="${REPO_ROOT}/${APP_PATH_REL}"
mkdir -p "$APP_PATH_ABS"

# ── Build env block ──
ENV_BLOCK=""
ENV_COUNT=$(yq '.env | length // 0' "$DESCRIPTOR")
if [[ "$ENV_COUNT" -gt 0 ]]; then
  ENV_BLOCK="        env:"
  for ((i=0; i<ENV_COUNT; i++)); do
    KEY=$(yq ".env[$i].name" "$DESCRIPTOR")
    VAL=$(yq ".env[$i].value" "$DESCRIPTOR")
    ENV_BLOCK="${ENV_BLOCK}
        - name: ${KEY}
          value: \"${VAL}\""
  done
fi

echo "📝 Rendering manifests for ${NAME} → ${APP_PATH_REL}/"

cat > "${APP_PATH_ABS}/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${NAME}
  labels:
    app: ${NAME}
    bcpxpress.yourco.io/itsi: "${ITSI}"
spec:
  replicas: ${REPLICAS}
  selector:
    matchLabels:
      app: ${NAME}
  template:
    metadata:
      labels:
        app: ${NAME}
    spec:
      containers:
      - name: ${NAME}
        image: ${IMAGE}
        ports:
        - containerPort: ${PORT}
${ENV_BLOCK}
EOF

cat > "${APP_PATH_ABS}/service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${NAME}
  labels:
    app: ${NAME}
spec:
  selector:
    app: ${NAME}
  ports:
  - port: 80
    targetPort: ${PORT}
EOF

# ── Commit + push ──
echo ""
echo "📤 Committing manifests to ${GITHUB_REPO_URL}..."
git -C "$REPO_ROOT" add "$APP_PATH_REL"
if git -C "$REPO_ROOT" diff --cached --quiet; then
  echo "   no manifest changes — skipping commit"
else
  git -C "$REPO_ROOT" commit -m "deploy(${NAME}): sync manifests"
  git -C "$REPO_ROOT" push
fi

# ── Create/update ArgoCD Application ──
echo ""
echo "🚀 Creating ArgoCD Application '${NAME}'..."
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${NAME}
  namespace: argocd
  annotations:
    bcpxpress.yourco.io/itsi: "${ITSI}"
spec:
  project: default
  source:
    repoURL: ${GITHUB_REPO_URL}
    targetRevision: HEAD
    path: ${APP_PATH_REL}
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

echo ""
echo "✅ ${NAME} deployed!"
echo ""
echo "Watch sync status:"
echo "  kubectl get application ${NAME} -n argocd -w"
echo ""
echo "Test it (with port-forward to the service):"
echo "  kubectl port-forward svc/${NAME} 8080:80"
echo "  curl http://localhost:8080/"
