#!/usr/bin/env bash
# status.sh — show status of all deployed apps or a specific one.
set -euo pipefail

APP="${1:-}"

if [ -z "$APP" ]; then
  echo "📋 All BCP Xpress apps:"
  echo ""
  kn service list
else
  echo "📋 App: ${APP}"
  echo ""
  kn service describe "$APP"
  echo ""
  echo "📊 Revisions:"
  kn revision list --service "$APP"
fi

