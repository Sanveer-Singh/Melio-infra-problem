#!/bin/bash
set -euxo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

ARTIFACTS=(
  "build/front-end.jar"
  "build/quotes.jar"
  "build/newsfeed.jar"
  "build/static.tgz"
)

echo "==> Checking prerequisites..."
java -version
lein version

echo "==> Installing common-utils to local Maven repo..."
make libs

echo "==> Building all artifacts..."
make clean all

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

echo "==> Local build complete."
