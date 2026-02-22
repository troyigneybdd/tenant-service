#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE_NAME="tenant-service"
IMAGE_TAG="${IMAGE_TAG:-latest}"
NAMESPACE="tenant-service"
DEPLOYMENT="tenant-service"

wait_for_deployment_delete() {
  local name="$1"
  local namespace="$2"
  local timeout="${3:-120s}"
  if kubectl get deploy -n "$namespace" "$name" >/dev/null 2>&1; then
    kubectl wait --for=delete "deployment/$name" -n "$namespace" --timeout="$timeout" || true
  fi
}

wait_for_image_removal() {
  local image="$1"
  local timeout="${2:-120s}"
  local start
  start="$(date +%s)"
  while minikube image ls --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -Fq "$image"; do
    if [ $(( $(date +%s) - start )) -ge "${timeout%s}" ]; then
      break
    fi
    sleep 2
    minikube image rm "$image" >/dev/null 2>&1 || true
  done
}

force_remove_image() {
  local image="$1"
  minikube image rm "$image" >/dev/null 2>&1 || true
  wait_for_image_removal "$image"
  if minikube image ls --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -Fq "$image"; then
    minikube ssh -- "sudo crictl rmi $image || sudo crictl rmi docker.io/library/$image" >/dev/null 2>&1 || true
  fi
}

minikube_image_load() {
  local image="$1"
  if minikube image load --help 2>/dev/null | grep -q overwrite; then
    minikube image load --overwrite "$image" || minikube image load "$image"
  else
    minikube image load "$image"
  fi
}

build_image() {
  local image="$1"
  local dockerfile="$2"
  local context="$3"
  if eval "$(minikube docker-env)" 2>/dev/null; then
    docker build --no-cache -t "$image" -f "$dockerfile" "$context" && return 0
  fi
  docker build --no-cache -t "$image" -f "$dockerfile" "$context"
  minikube_image_load "$image"
}

echo "Deleting deployment ${DEPLOYMENT} in namespace ${NAMESPACE}..."
kubectl delete deploy -n "$NAMESPACE" "$DEPLOYMENT" --ignore-not-found=true
wait_for_deployment_delete "$DEPLOYMENT" "$NAMESPACE"

echo "Removing minikube image ${IMAGE_NAME}:${IMAGE_TAG}..."
force_remove_image "${IMAGE_NAME}:${IMAGE_TAG}"

echo "Building image ${IMAGE_NAME}:${IMAGE_TAG}..."
build_image "${IMAGE_NAME}:${IMAGE_TAG}" "$SERVICE_DIR/src/Dockerfile" "$SERVICE_DIR"

echo "Applying deployment..."
"$SCRIPT_DIR/apply.sh"
