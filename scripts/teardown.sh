#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_ROOT/terraform"
BOOTSTRAP_DIR="$TF_DIR/bootstrap"

AWS_PROFILE="${AWS_PROFILE:-charteracademy}"
AWS_REGION="${AWS_REGION:-af-south-1}"
AUTO_APPROVE=false

usage() {
  echo "Usage: $0 [-y]"
  echo "  -y   Skip confirmation prompt (for CI)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y) AUTO_APPROVE=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ "$AUTO_APPROVE" != "true" ]]; then
  echo "WARNING: This will destroy ALL infrastructure (main + bootstrap)."
  echo "Region: $AWS_REGION | Profile: $AWS_PROFILE"
  read -rp "Type 'yes' to confirm: " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

empty_s3_bucket() {
  local bucket="$1"
  echo "  Emptying bucket: $bucket"

  aws s3 rm "s3://$bucket" --recursive \
    --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null || true

  for pass in 1 2 3; do
    local version_keys version_ids
    version_keys=()
    version_ids=()
    while IFS=$'\t' read -r key vid; do
      [[ -n "$key" ]] && version_keys+=("$key") && version_ids+=("$vid")
    done < <(aws s3api list-object-versions --bucket "$bucket" \
      --profile "$AWS_PROFILE" --region "$AWS_REGION" \
      --query 'Versions[].{K:Key,V:VersionId}' \
      --output text 2>/dev/null || true)

    for idx in "${!version_keys[@]}"; do
      aws s3api delete-object --bucket "$bucket" \
        --key "${version_keys[$idx]}" --version-id "${version_ids[$idx]}" \
        --profile "$AWS_PROFILE" --region "$AWS_REGION" --output text 2>/dev/null || true
    done

    local marker_keys marker_ids
    marker_keys=()
    marker_ids=()
    while IFS=$'\t' read -r key vid; do
      [[ -n "$key" ]] && marker_keys+=("$key") && marker_ids+=("$vid")
    done < <(aws s3api list-object-versions --bucket "$bucket" \
      --profile "$AWS_PROFILE" --region "$AWS_REGION" \
      --query 'DeleteMarkers[].{K:Key,V:VersionId}' \
      --output text 2>/dev/null || true)

    for idx in "${!marker_keys[@]}"; do
      aws s3api delete-object --bucket "$bucket" \
        --key "${marker_keys[$idx]}" --version-id "${marker_ids[$idx]}" \
        --profile "$AWS_PROFILE" --region "$AWS_REGION" --output text 2>/dev/null || true
    done

    local remaining
    remaining=$(aws s3api list-object-versions --bucket "$bucket" \
      --profile "$AWS_PROFILE" --region "$AWS_REGION" \
      --query 'length(Versions || `[]`) + length(DeleteMarkers || `[]`)' \
      --output text 2>/dev/null) || remaining="0"
    if [[ "$remaining" == "0" || "$remaining" == "None" ]]; then
      echo "  Bucket $bucket is empty."
      break
    fi
    echo "  $remaining objects remain (pass $pass), retrying..."
  done
}

echo ""
echo "=== Step 1/6: Destroy main infrastructure ==="
if [[ -d "$TF_DIR/.terraform" ]]; then
  cd "$TF_DIR"
  terraform init -input=false -no-color 2>/dev/null || true
  terraform destroy -auto-approve -input=false \
    -var='newsfeed_service_token=teardown-placeholder' 2>&1 || {
    echo "WARN: First destroy attempt failed (likely DynamoDB lock issue). Retrying with -lock=false..."
    terraform destroy -auto-approve -input=false -lock=false \
      -var='newsfeed_service_token=teardown-placeholder' || {
      echo "WARN: Main terraform destroy returned non-zero. May already be destroyed."
    }
  }
  cd "$PROJECT_ROOT"
else
  echo "SKIP: $TF_DIR/.terraform not found (main infra may not have been initialized)."
fi

echo ""
echo "=== Step 2/6: Disable prevent_destroy on state bucket ==="
if [[ ! -f "$BOOTSTRAP_DIR/terraform.tfstate" ]]; then
  echo "ERROR: $BOOTSTRAP_DIR/terraform.tfstate not found."
  echo "  Bootstrap resources are orphaned -- manual cleanup required."
  echo "  Check S3 buckets and DynamoDB table in $AWS_REGION via AWS Console."
  exit 1
fi

cd "$BOOTSTRAP_DIR"

if grep -q 'prevent_destroy = true' main.tf 2>/dev/null; then
  sed -i.bak 's/prevent_destroy = true/prevent_destroy = false/g' main.tf
  echo "  Flipped prevent_destroy to false in bootstrap/main.tf"
else
  echo "  prevent_destroy already false or not found -- continuing."
fi

echo ""
echo "=== Step 3/6: Apply bootstrap change (disable prevent_destroy) ==="
terraform init -input=false -no-color 2>/dev/null || true
terraform apply -auto-approve -input=false || {
  echo "WARN: Bootstrap apply failed. Attempting direct destroy."
}

echo ""
echo "=== Step 4/6: Empty S3 buckets (state bucket lacks force_destroy) ==="
STATE_BUCKET=$(terraform output -raw state_bucket_name 2>/dev/null) || STATE_BUCKET=""
ARTIFACT_BUCKET=$(terraform output -raw artifact_bucket_name 2>/dev/null) || ARTIFACT_BUCKET=""

if [[ -n "$STATE_BUCKET" ]]; then
  empty_s3_bucket "$STATE_BUCKET"
fi
if [[ -n "$ARTIFACT_BUCKET" ]]; then
  empty_s3_bucket "$ARTIFACT_BUCKET"
fi

echo ""
echo "=== Step 5/6: Destroy bootstrap infrastructure ==="
terraform destroy -auto-approve -input=false || {
  echo "ERROR: Bootstrap destroy failed."
  echo "  Manual cleanup may be needed for: S3 buckets, DynamoDB table."
  exit 1
}

echo ""
echo "=== Step 6/6: Restore bootstrap code and verify cleanup ==="
cd "$PROJECT_ROOT"
git checkout -- terraform/bootstrap/main.tf 2>/dev/null || {
  if [[ -f "$BOOTSTRAP_DIR/main.tf.bak" ]]; then
    mv "$BOOTSTRAP_DIR/main.tf.bak" "$BOOTSTRAP_DIR/main.tf"
    echo "  Restored main.tf from .bak file"
  fi
}
rm -f "$BOOTSTRAP_DIR/main.tf.bak" 2>/dev/null || true

echo ""
echo "==> Verifying no lingering resources (tag: ManagedBy=terraform)..."
REMAINING=$(aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=ManagedBy,Values=terraform \
  --region "$AWS_REGION" --profile "$AWS_PROFILE" \
  --query 'ResourceTagMappingList[*].ResourceARN' --output text 2>/dev/null) || REMAINING=""

if [[ -z "$REMAINING" || "$REMAINING" == "None" ]]; then
  echo "  No lingering resources found. Cleanup complete."
else
  echo "  WARNING: Lingering resources found:"
  echo "$REMAINING"
  echo "  Manual cleanup may be needed."
fi

echo ""
echo "=== Teardown complete ==="
echo "  Removed: main infra, S3 buckets, DynamoDB lock table"
echo "  Bootstrap local state is now stale (expected)."
