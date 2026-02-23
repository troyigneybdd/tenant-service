#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE_NAME="tenant-service"
IMAGE_TAG="${IMAGE_TAG:-latest}"
BUILD_TIME="${BUILD_TIME:-$(date +"%Y%m%d-%H%M%S")}"
NAMESPACE="tenant-service"
DEPLOYMENT="tenant-service"

scale_down_deployment() {
  local name="$1"
  local namespace="$2"
  local timeout="${3:-120s}"
  if kubectl get deploy -n "$namespace" "$name" >/dev/null 2>&1; then
    kubectl scale deploy -n "$namespace" "$name" --replicas=0 || true
    kubectl wait --for=delete pod -n "$namespace" -l "app=$name" --timeout="$timeout" || true
  fi
}

scale_up_deployment() {
  local name="$1"
  local namespace="$2"
  local replicas="${3:-1}"
  local timeout="${4:-180s}"
  if kubectl get deploy -n "$namespace" "$name" >/dev/null 2>&1; then
    kubectl scale deploy -n "$namespace" "$name" --replicas="$replicas" || true
    kubectl rollout status deployment/"$name" -n "$namespace" --timeout="$timeout" || true
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
  echo "Removing local Docker image ${image}..."
  docker image rm "$image" >/dev/null 2>&1 || true
  echo "Removing minikube image cache ${image}..."
  minikube image rm "$image" >/dev/null 2>&1 || true
  wait_for_image_removal "$image"
  if minikube image ls --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -Fq "$image"; then
    echo "Removing minikube containerd image ${image}..."
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

prune_all_minikube_image_tags() {
  local image_refs
  image_refs="$(minikube image ls --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)"
  if [ -n "$image_refs" ]; then
    echo "$image_refs" | awk -F: '$NF!="latest" {print $0}' | while read -r ref; do \
      if [ -n "$ref" ]; then minikube image rm "$ref" >/dev/null 2>&1 || true; fi; \
    done; \
  fi
  minikube ssh -- "sudo crictl images | awk '\$2==\"latest\" {print \$1}' | sort -u | while read name; do \
    latest_id=\$(sudo crictl images | awk -v n=\"\$name\" '\$1==n && \$2==\"latest\" {print \$3; exit}'); \
    if [ -z \"\$latest_id\" ]; then continue; fi; \
    sudo crictl images | awk -v n=\"\$name\" '\$1==n && \$2!=\"latest\" {print \$1\":\"\$2}' | while read img; do \
      if [ -n \"\$img\" ]; then sudo crictl rmi \"\$img\" >/dev/null 2>&1 || true; fi; \
    done; \
    sudo crictl images | awk -v n=\"\$name\" -v latest=\"\$latest_id\" '\$1==n && \$3!=latest {print \$3}' | sort -u | while read id; do \
      if [ -n \"\$id\" ]; then sudo crictl rmi \"\$id\" >/dev/null 2>&1 || true; fi; \
    done; \
  done" >/dev/null 2>&1 || true
}

hash_dir() {
  local dir="$1"
  if command -v git &> /dev/null && git -C "$SERVICE_DIR" rev-parse --is-inside-work-tree &> /dev/null; then
    git -C "$SERVICE_DIR" ls-files -z --cached --others --exclude-standard -- "$dir" \
      | xargs -0 -I{} sh -c 'printf "%s\0" "{}"; cat "$1" 2>/dev/null' _ "$SERVICE_DIR/{}" \
      | sha256sum | awk '{print $1}'
    return 0
  fi

  if command -v sha256sum &> /dev/null; then
    find "$dir" -type f -not -path "*/node_modules/*" -not -path "*/.git/*" -print0 \
      | sort -z \
      | xargs -0 -I{} sh -c 'printf "%s\0" "{}"; cat "{}" 2>/dev/null' \
      | sha256sum \
      | awk '{print $1}'
    return 0
  fi

  echo ""
}

compute_extra_tags() {
  local context="$1"
  local hash
  hash="$(hash_dir "$context")"
  if [ -z "$hash" ]; then
    echo "$BUILD_TIME"
    return 0
  fi
  echo "$BUILD_TIME $hash"
}

tag_image_with_extras() {
  local image="$1"
  local tags="$2"
  local tag
  for tag in $tags; do
    docker tag "$image" "${image%:*}:$tag"
  done
}

build_image() {
  local image="$1"
  local dockerfile="$2"
  local context="$3"
  local extra_tags
  extra_tags="$(compute_extra_tags "$context")"
  echo "Building image (local Docker): ${image}"
  docker build --no-cache -t "$image" -f "$dockerfile" "$context"
  tag_image_with_extras "$image" "$extra_tags"
  if minikube docker-env &> /dev/null; then
    echo "Building image (minikube Docker): ${image}"
    ( eval "$(minikube docker-env)" \
      && docker build --no-cache -t "$image" -f "$dockerfile" "$context" \
      && tag_image_with_extras "$image" "$extra_tags" )
  else
    echo "Loading image into minikube: ${image}"
    minikube_image_load "$image"
    for tag in $extra_tags; do
      minikube_image_load "${image%:*}:$tag"
    done
  fi
}

echo "Scaling deployment ${DEPLOYMENT} in namespace ${NAMESPACE} to 0..."
scale_down_deployment "$DEPLOYMENT" "$NAMESPACE"

echo "Removing minikube image ${IMAGE_NAME}:${IMAGE_TAG}..."
force_remove_image "${IMAGE_NAME}:${IMAGE_TAG}"

echo "Building image ${IMAGE_NAME}:${IMAGE_TAG}..."
build_image "${IMAGE_NAME}:${IMAGE_TAG}" "$SERVICE_DIR/src/Dockerfile" "$SERVICE_DIR"
echo "Pruning minikube image tags (keep :latest only)..."
prune_all_minikube_image_tags

echo "Scaling deployment ${DEPLOYMENT} in namespace ${NAMESPACE} back up..."
scale_up_deployment "$DEPLOYMENT" "$NAMESPACE"
