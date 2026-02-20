#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
while [ ! -f "$ROOT_DIR/deploy/scripts/01_lib.sh" ] && [ "$ROOT_DIR" != "/" ]; do
  ROOT_DIR="$(cd "$ROOT_DIR/.." && pwd)"
done
if [ ! -f "$ROOT_DIR/deploy/scripts/01_lib.sh" ]; then
  echo "Failed to locate deploy/scripts/01_lib.sh" >&2
  exit 1
fi

source "$ROOT_DIR/deploy/scripts/01_lib.sh"

log "Deploying Tenants API..."

if [ "$DRY_RUN" = "false" ]; then
  kubectl apply -f "$SCRIPT_DIR/tenants-api.yaml" >> "$LOG_FILE" 2>&1 || error "Failed to deploy Tenants API"
  wait_for_deployment "tenants-api" "tenants-api" 180
else
  info "[DRY RUN] Would deploy: kubectl apply -f $SCRIPT_DIR/tenants-api.yaml"
fi

log "Tenants API deployed"
