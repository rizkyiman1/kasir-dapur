#!/usr/bin/env bash
# Health check for deployment / systemd / monitoring.
# Usage:
#   HEALTH_URL=http://127.0.0.1:8080/health bash deploy/health-check.sh

set -euo pipefail

URL="${HEALTH_URL:-http://127.0.0.1:8080/health}"
HTTP_CODE="$(curl -sS -o /tmp/dapur-kasir-health.json -w '%{http_code}' "${URL}")"

if [[ "${HTTP_CODE}" != "200" ]]; then
  echo "FAIL: ${URL} returned HTTP ${HTTP_CODE}"
  exit 1
fi

if ! grep -q '"ok"[[:space:]]*:[[:space:]]*true' /tmp/dapur-kasir-health.json; then
  echo "FAIL: health body missing ok:true"
  exit 1
fi

echo "PASS: ${URL} HTTP 200 ok:true"
cat /tmp/dapur-kasir-health.json
echo ""
