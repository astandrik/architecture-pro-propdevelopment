#!/bin/bash
set -euo pipefail

PASS=0
FAIL=0

check_connection() {
  local FROM_ROLE=$1
  local TO_SERVICE=$2
  local EXPECT=$3
  local TEST_NAME="test-${FROM_ROLE}-to-$(echo "${TO_SERVICE}" | cut -d. -f1)-${RANDOM}"

  echo -n "  ${FROM_ROLE} -> ${TO_SERVICE} (ожидание: ${EXPECT}): "

  RESULT=$(kubectl run "${TEST_NAME}" \
    --image=alpine \
    --labels="role=${FROM_ROLE}" \
    --restart=Never \
    --rm -i \
    --timeout=30s \
    -- wget -qO- --timeout=2 "http://${TO_SERVICE}" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

  if [ "${EXPECT}" = "allow" ]; then
    if [ ${EXIT_CODE} -eq 0 ]; then
      echo "OK (соединение разрешено)"
      PASS=$((PASS + 1))
    else
      echo "FAIL (соединение должно быть разрешено, но заблокировано)"
      FAIL=$((FAIL + 1))
    fi
  else
    if [ ${EXIT_CODE} -ne 0 ]; then
      echo "OK (соединение заблокировано)"
      PASS=$((PASS + 1))
    else
      echo "FAIL (соединение должно быть заблокировано, но прошло)"
      FAIL=$((FAIL + 1))
    fi
  fi
}

echo "=== Проверка сетевых политик ==="
echo ""

echo "--- Разрешённые соединения (должны пройти) ---"
check_connection "front-end"           "back-end-api-app"          "allow"
check_connection "back-end-api"        "front-end-app"             "allow"
check_connection "admin-front-end"     "admin-back-end-api-app"    "allow"
check_connection "admin-back-end-api"  "admin-front-end-app"       "allow"

echo ""
echo "--- Запрещённые соединения (должны быть заблокированы) ---"
check_connection "front-end"           "admin-back-end-api-app"    "deny"
check_connection "admin-front-end"     "back-end-api-app"          "deny"
check_connection "front-end"           "admin-front-end-app"       "deny"
check_connection "back-end-api"        "admin-back-end-api-app"    "deny"

echo ""
echo "=== Итого: ${PASS} passed, ${FAIL} failed ==="

if [ ${FAIL} -gt 0 ]; then
  exit 1
fi
