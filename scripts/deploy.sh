#!/bin/bash
set -euxo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

ARTIFACT_BUCKET="${1:-$(cd terraform/bootstrap && terraform output -raw artifact_bucket_name)}"
AWS_PROFILE="${AWS_PROFILE:-charteracademy}"
REGION="${AWS_REGION:-af-south-1}"

ARTIFACTS=(
  "build/front-end.jar"
  "build/quotes.jar"
  "build/newsfeed.jar"
  "build/static.tgz"
)

echo "==> Verifying build artifacts exist..."
missing=0
for artifact in "${ARTIFACTS[@]}"; do
  if [[ ! -f "$artifact" ]]; then
    echo "ERROR: Missing artifact: $artifact -- run build-docker.sh or build-local.sh first"
    missing=1
  fi
done

if [[ "$missing" -eq 1 ]]; then
  exit 1
fi

echo "==> Uploading artifacts to s3://${ARTIFACT_BUCKET}/..."
for artifact in "${ARTIFACTS[@]}"; do
  aws s3 cp "$artifact" "s3://${ARTIFACT_BUCKET}/$(basename "$artifact")" \
    --profile "$AWS_PROFILE" \
    --region "$REGION"
done

echo "==> Verifying uploads..."
aws s3 ls "s3://${ARTIFACT_BUCKET}/" --profile "$AWS_PROFILE" --region "$REGION"

echo "==> Deploy complete. Artifacts in s3://${ARTIFACT_BUCKET}/"
