#!/bin/bash
set -euo pipefail

echo "=== Gatekeeper: readOnlyRootFilesystem (PSA не проверяет) ==="
echo ""

cat <<'EOF' | kubectl apply -f - 2>&1 && RESULT="admitted" || RESULT="rejected"
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

echo ""

if [ "$RESULT" = "rejected" ]; then
  echo "PASS: pod без readOnlyRootFilesystem отклонён Gatekeeper"
else
  echo "FAIL: pod принят -- Gatekeeper не отклонил (constraint применён?)"
  kubectl delete pod test-gatekeeper-only -n audit-zone --ignore-not-found --wait=false 2>/dev/null || true
  exit 1
fi
