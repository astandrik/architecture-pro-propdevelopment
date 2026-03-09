#!/bin/bash
set -euo pipefail

echo "=== Gatekeeper: readOnlyRootFilesystem (PSA не проверяет) ==="
echo ""

if OUTPUT=$(
  cat <<'EOF' | kubectl apply -f - 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: test-gatekeeper-only
  namespace: audit-zone
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: test
      image: busybox
      command: ["sleep", "10"]
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
EOF
); then
  STATUS=0
else
  STATUS=$?
fi

echo ""

if [ "$STATUS" -ne 0 ]; then
  if printf '%s\n' "$OUTPUT" | grep -Eq "readOnlyRootFilesystem|require-readonly-rootfs|validation.gatekeeper.sh"; then
    echo "PASS: pod без readOnlyRootFilesystem отклонён Gatekeeper"
  else
    echo "FAIL: pod отклонён, но причина не похожа на правило Gatekeeper"
    echo "$OUTPUT"
    exit 1
  fi
else
  echo "FAIL: pod принят -- Gatekeeper не отклонил (constraint применён?)"
  kubectl delete pod test-gatekeeper-only -n audit-zone --ignore-not-found --wait=false 2>/dev/null || true
  exit 1
fi
