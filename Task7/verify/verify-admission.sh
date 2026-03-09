#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TASK_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0

check_rejected() {
  local manifest="$1"
  local label="$2"
  if kubectl apply -f "$manifest" 2>/dev/null; then
    echo "  FAIL: $label — pod was admitted (expected rejection)"
    kubectl delete -f "$manifest" --ignore-not-found --wait=false 2>/dev/null || true
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $label — rejected by admission"
    PASS=$((PASS + 1))
  fi
}

check_admitted() {
  local manifest="$1"
  local label="$2"
  if kubectl apply -f "$manifest" 2>/dev/null; then
    echo "  PASS: $label — admitted"
    kubectl delete -f "$manifest" --ignore-not-found --wait=false 2>/dev/null || true
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — rejected (expected admission)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Проверка: insecure manifests должны быть отклонены ==="
echo ""

for manifest in "$TASK_DIR"/insecure-manifests/*.yaml; do
  name=$(basename "$manifest")
  check_rejected "$manifest" "$name"
done

echo ""
echo "=== Проверка: secure manifests должны быть приняты ==="
echo ""

for manifest in "$TASK_DIR"/secure-manifests/*.yaml; do
  name=$(basename "$manifest")
  check_admitted "$manifest" "$name"
done

echo ""
echo "=== Итог: PASS=$PASS  FAIL=$FAIL ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
