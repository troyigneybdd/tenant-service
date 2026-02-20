#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib.sh"

log "Deploying Tenant Service..."

if [ "$DRY_RUN" = "false" ]; then
  kubectl apply -f "$SCRIPT_DIR/tenant-service.yaml" >> "$LOG_FILE" 2>&1 || error "Failed to deploy Tenant Service"
  wait_for_deployment "tenant-service" "tenant-service" 180
else
  info "[DRY RUN] Would deploy: kubectl apply -f $SCRIPT_DIR/tenant-service.yaml"
fi

log "Tenant Service deployed"
