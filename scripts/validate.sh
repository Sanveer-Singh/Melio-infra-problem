#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_ROOT/terraform"

MAX_ATTEMPTS="${MAX_ATTEMPTS:-10}"
WAIT_SECONDS="${WAIT_SECONDS:-15}"
ALB_DNS=""

usage() {
  echo "Usage: $0 [--alb-dns <dns-name>]"
  echo "  --alb-dns   Override ALB DNS (skips terraform output lookup)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --alb-dns) ALB_DNS="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$ALB_DNS" ]]; then
  echo "==> Reading ALB DNS from terraform output..."
  ALB_DNS=$(cd "$TF_DIR" && terraform output -raw alb_dns_name 2>/dev/null) || {
    echo "ERROR: Could not read alb_dns_name from terraform output."
    echo "  Ensure 'terraform apply' has been run in $TF_DIR"
    echo "  Or pass --alb-dns <dns-name> manually."
    exit 1
  }
fi

BASE_URL="http://${ALB_DNS}"
echo "==> Validating application at: $BASE_URL"
echo "==> Max attempts: $MAX_ATTEMPTS, interval: ${WAIT_SECONDS}s"
echo ""

PASS=0
FAIL=0

check_endpoint() {
  local path="$1"
  local description="$2"
  local expect_body="${3:-}"
  local url="${BASE_URL}${path}"

  echo "--- Checking: $description ($url)"

  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    HTTP_CODE=$(curl -s -o /tmp/validate_body.txt -w "%{http_code}" --connect-timeout 5 --max-time 15 "$url" 2>/dev/null) || HTTP_CODE="000"

    if [[ "$HTTP_CODE" == "200" ]]; then
      if [[ -n "$expect_body" ]]; then
        if grep -qi "$expect_body" /tmp/validate_body.txt 2>/dev/null; then
          echo "  PASS (HTTP $HTTP_CODE, body contains '$expect_body') [attempt $attempt]"
          PASS=$((PASS + 1))
          return 0
        else
          echo "  WARN: HTTP 200 but body missing '$expect_body' [attempt $attempt]"
        fi
      else
        echo "  PASS (HTTP $HTTP_CODE) [attempt $attempt]"
        PASS=$((PASS + 1))
        return 0
      fi
    else
      echo "  Attempt $attempt/$MAX_ATTEMPTS: HTTP $HTTP_CODE -- retrying in ${WAIT_SECONDS}s..."
    fi

    if [[ "$attempt" -lt "$MAX_ATTEMPTS" ]]; then
      sleep "$WAIT_SECONDS"
    fi
  done

  echo "  FAIL: $description did not pass after $MAX_ATTEMPTS attempts"
  FAIL=$((FAIL + 1))
  return 1
}

check_endpoint "/ping" "Health check (nginx + JVM)" || true
check_endpoint "/" "Homepage (frontend + quotes)" "quote" || true
check_endpoint "/css/bootstrap.min.css" "Static CSS (nginx serving)" || true

echo ""
echo "========================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "========================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Debug guidance:"
  echo "  1. SSH to frontend: ssh -i <key.pem> ec2-user@<frontend-ip>"
  echo "  2. Check cloud-init: sudo cat /var/log/cloud-init-output.log"
  echo "  3. Check services:   systemctl status frontend nginx"
  echo "  4. Check JVM logs:   journalctl -u frontend --no-pager -n 50"
  echo "  5. Check nginx:      nginx -t && journalctl -u nginx --no-pager -n 50"
  exit 1
fi

echo ""
echo "All checks passed. Application is healthy."
exit 0
