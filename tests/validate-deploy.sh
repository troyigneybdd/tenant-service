#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log() { echo "$@"; }

if ! command -v kubectl &> /dev/null; then
  log "kubectl not found; skipping deploy validation."
  exit 0
fi

if ! command -v helm &> /dev/null; then
  log "helm not found; helm validation will be skipped."
  HELM_AVAILABLE=false
else
  HELM_AVAILABLE=true
fi

VALIDATE_MODE="${KUBECTL_VALIDATE_MODE:-client}"
KUBECTL_FLAGS=(--dry-run=client --validate=false)
if [ "$VALIDATE_MODE" = "server" ]; then
  if kubectl cluster-info &> /dev/null; then
    KUBECTL_FLAGS=(--dry-run=server)
  else
    log "Cluster not reachable; falling back to client validation."
    VALIDATE_MODE="client"
  fi
fi

log "Validating deploy and helm manifests in $REPO_ROOT (kubectl: $VALIDATE_MODE)"

DEPLOY_DIR="$REPO_ROOT/deploy"
if [ -d "$DEPLOY_DIR" ]; then
  shopt -s nullglob
  for manifest in "$DEPLOY_DIR"/*.yaml "$DEPLOY_DIR"/*.yml; do
    log "kubectl apply ${KUBECTL_FLAGS[*]} -f $manifest"
    if ! kubectl apply "${KUBECTL_FLAGS[@]}" -f "$manifest" >/dev/null; then
      if [ "$VALIDATE_MODE" = "server" ]; then
        log "Server dry-run failed; retrying client validation for $manifest"
        kubectl apply --dry-run=client --validate=false -f "$manifest" >/dev/null
      else
        return 1
      fi
    fi
  done
  shopt -u nullglob
else
  log "No deploy directory found."
fi

HELM_DIR="$REPO_ROOT/helm"
if [ "$HELM_AVAILABLE" = "true" ] && [ -d "$HELM_DIR" ]; then
  shopt -s nullglob
  for chart in "$HELM_DIR"/*; do
    if [ -d "$chart" ] && [ -f "$chart/Chart.yaml" ]; then
      log "helm template $chart"
      rendered="$(helm template "$chart")"
      if [ -n "$rendered" ]; then
        if ! printf "%s\n" "$rendered" | kubectl apply "${KUBECTL_FLAGS[@]}" -f - >/dev/null; then
          if [ "$VALIDATE_MODE" = "server" ]; then
            log "Server dry-run failed; retrying client validation for $chart"
            printf "%s\n" "$rendered" | kubectl apply --dry-run=client --validate=false -f - >/dev/null
          else
            return 1
          fi
        fi
      fi
    fi
  done
  shopt -u nullglob
else
  log "No helm directory found or helm not installed."
fi

log "Deploy validation completed."
