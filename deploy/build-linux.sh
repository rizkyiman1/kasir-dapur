#!/usr/bin/env bash
# Build Kasir Dapur backend binary on Linux VPS.
# Usage (from repo root or backend/):
#   bash deploy/build-linux.sh
# Output: /opt/dapur-kasir/bin/kasir-dapur-backend (override with OUT_DIR)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/../backend" && pwd)"
OUT_DIR="${OUT_DIR:-/opt/dapur-kasir/bin}"
OUT_BIN="${OUT_DIR}/kasir-dapur-backend"

command -v dart >/dev/null 2>&1 || {
  echo "ERROR: Dart SDK not found. Install Dart ^3.13.0 first."
  exit 1
}

DART_VERSION="$(dart --version 2>&1 | head -n1)"
echo "Using ${DART_VERSION}"

mkdir -p "${OUT_DIR}"
cd "${BACKEND_DIR}"
dart pub get
dart compile exe bin/server.dart -o "${OUT_BIN}"
chmod 755 "${OUT_BIN}"

echo "Built: ${OUT_BIN}"
echo "Run: ${OUT_BIN} (with EnvironmentFile or .env in working directory)"
