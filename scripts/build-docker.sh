#!/bin/bash
set -euxo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

CONTAINER_NAME="melio-build-extract"
IMAGE_NAME="melio-build"
ARTIFACTS=(
  "build/front-end.jar"
  "build/quotes.jar"
  "build/newsfeed.jar"
  "build/static.tgz"
)

echo "==> Building artifacts via Docker..."
docker build -t "$IMAGE_NAME" -f scripts/Dockerfile.build .

mkdir -p build

docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
docker create --name "$CONTAINER_NAME" "$IMAGE_NAME"
docker cp "$CONTAINER_NAME":/app/build/. ./build/
docker rm "$CONTAINER_NAME"

echo "==> Verifying artifacts..."
missing=0
for artifact in "${ARTIFACTS[@]}"; do
  if [[ ! -f "$artifact" ]]; then
    echo "ERROR: Missing artifact: $artifact"
    missing=1
  fi
done

if [[ "$missing" -eq 1 ]]; then
  echo "ERROR: Build failed -- missing artifacts"
  exit 1
fi

echo "==> Artifact sizes:"
ls -lh build/

echo "==> Build complete."
