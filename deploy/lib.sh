#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="${LOG_FILE:-$ROOT_DIR/deploy.log}"
DRY_RUN="${DRY_RUN:-false}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
  exit 1
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
  echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

wait_for_deployment() {
  local namespace=$1
  local deployment=$2
  local timeout=${3:-300}

  log "Waiting for deployment $deployment in namespace $namespace..."

  if [ "$DRY_RUN" = "true" ]; then
    info "[DRY RUN] Would wait for deployment: kubectl rollout status deployment/$deployment -n $namespace --timeout=${timeout}s"
    return 0
  fi

  if kubectl rollout status "deployment/$deployment" -n "$namespace" --timeout="${timeout}s" >> "$LOG_FILE" 2>&1; then
    log "Deployment $deployment in $namespace is ready"
    return 0
  fi

  error "Deployment $deployment in $namespace did not become ready within ${timeout}s"
}

helm_release_deployed() {
  local release=$1
  local namespace=$2

  if ! command -v helm &> /dev/null; then
    return 1
  fi

  local status
  status=$(helm status "$release" -n "$namespace" --output json 2>/dev/null | awk -F '"status"' '{print $2}' | awk -F '"' '{print $3}')
  if [ "$status" = "deployed" ]; then
    return 0
  fi
  return 1
}

helm_install_or_skip() {
  local release=$1
  local namespace=$2
  shift 2

  if helm_release_deployed "$release" "$namespace"; then
    log "Helm release $release in $namespace already deployed; skipping"
    return 0
  fi

  if [ "$DRY_RUN" = "true" ]; then
    info "[DRY RUN] Would run: helm upgrade --install $release $* -n $namespace --create-namespace --wait --timeout 5m"
    return 0
  fi

  helm upgrade --install "$release" "$@" -n "$namespace" --create-namespace --wait --timeout 5m >> "$LOG_FILE" 2>&1 || error "Helm install/upgrade failed for $release"
}
