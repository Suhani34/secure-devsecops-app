#!/usr/bin/env bash

set -euo pipefail


echo
echo "=========================================="
echo " Secure DevSecOps Final Security Audit"
echo "=========================================="
echo


echo "[1/8] Validating Docker Compose configuration"

sudo docker compose config -q


echo
echo "[2/8] Running Python tests and coverage"

python -m pytest \
  -v \
  --cov=app \
  --cov-report=term-missing \
  --cov-report=xml \
  --cov-fail-under=80


echo
echo "[3/8] Running Git history secret scan"

gitleaks git \
  --redact \
  .


echo
echo "[4/8] Running Semgrep SAST"

semgrep scan \
  --config auto \
  --error \
  .


echo
echo "[5/8] Running Trivy repository security gate"

trivy fs \
  --scanners vuln,misconfig \
  --file-patterns 'pip:requirements-dev\.txt' \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  --skip-dirs .venv \
  --skip-dirs .git \
  --skip-dirs secrets \
  .


echo
echo "[6/8] Starting hardened runtime"

sudo docker compose up \
  -d \
  --build


echo
echo "[7/8] Running runtime security validation"

./scripts/runtime-security-checks.sh


echo
echo "[8/8] Scanning application Docker image"

sudo trivy image \
  --scanners vuln \
  --pkg-types os,library \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  --exit-on-eol 1 \
  secure-task-api:0.3


echo
echo "=========================================="
echo " FINAL SECURITY AUDIT PASSED"
echo "=========================================="
