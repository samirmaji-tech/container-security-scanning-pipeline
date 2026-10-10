#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${1:-devsecops-web:1.0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker CLI is not installed or not in PATH." >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker Desktop/daemon is not running or the current user cannot access it." >&2
  echo "Open Docker Desktop, wait until it is ready, then retry: docker ps" >&2
  exit 1
fi
if ! command -v trivy >/dev/null 2>&1; then
  echo "ERROR: Trivy is not installed. On macOS with Homebrew, run: brew install trivy" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/reports"
echo "[1/3] Building image: $IMAGE_NAME"
docker build --pull -t "$IMAGE_NAME" "$ROOT_DIR"
echo "[2/3] Scanning image and writing text report"
trivy image --scanners vuln --severity HIGH,CRITICAL --format table --output "$ROOT_DIR/reports/trivy-report.txt" "$IMAGE_NAME"
echo "[3/3] Writing JSON report"
trivy image --scanners vuln --format json --output "$ROOT_DIR/reports/trivy-report.json" "$IMAGE_NAME"
echo "Done. Reports saved to:"
echo "  $ROOT_DIR/reports/trivy-report.txt"
echo "  $ROOT_DIR/reports/trivy-report.json"
echo "A scan with zero HIGH/CRITICAL findings is still a valid result; report what the scan actually shows."
