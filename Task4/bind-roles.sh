#!/bin/bash
set -euo pipefail

prepare_log_check_pod() {
  local NAMESPACE=$1
  local POD_NAME=$2
  local MESSAGE=$3

  kubectl delete pod "${POD_NAME}" -n "${NAMESPACE}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl run "${POD_NAME}" \
    -n "${NAMESPACE}" \
    --image=busybox \
    --restart=Never \
    --command -- sh -c "echo ${MESSAGE}; sleep 300" >/dev/null
  kubectl wait -n "${NAMESPACE}" --for=condition=Ready "pod/${POD_NAME}" --timeout=90s >/dev/null
}

echo "=== Привязка группы platform-admins к ClusterRole cluster-admin ==="

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: platform-admins-cluster-admin
subjects:
  - kind: Group
    name: platform-admins
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

echo "--- platform-admins → cluster-admin (весь кластер) ---"
echo ""

echo "=== Привязка dev-sales к namespace-admin в namespace sales ==="

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-sales-namespace-admin
  namespace: sales
subjects:
  - kind: User
    name: dev-sales
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: namespace-admin
  apiGroup: rbac.authorization.k8s.io
EOF

echo "--- dev-sales → namespace-admin (только sales) ---"
echo ""

echo "=== Привязка analyst-tenant к namespace-viewer в namespace tenant-services ==="

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: analyst-tenant-namespace-viewer
  namespace: tenant-services
subjects:
  - kind: User
    name: analyst-tenant
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: namespace-viewer
  apiGroup: rbac.authorization.k8s.io
EOF

echo "--- analyst-tenant → namespace-viewer (только tenant-services) ---"
echo ""

echo "=== Все привязки созданы ==="
echo ""
echo "ClusterRoleBindings:"
kubectl get clusterrolebindings platform-admins-cluster-admin --no-headers
echo ""
echo "RoleBindings:"
echo "  namespace: sales"
kubectl get rolebindings -n sales --no-headers
echo "  namespace: tenant-services"
kubectl get rolebindings -n tenant-services --no-headers
echo ""

prepare_log_check_pod "sales" "rbac-log-check-sales" "sales-log-check"
prepare_log_check_pod "tenant-services" "rbac-log-check-tenant" "tenant-log-check"

echo "=== Проверка прав доступа ==="
echo ""
echo "security-admin (platform-admins) — доступ к secrets:"
kubectl auth can-i get secrets --as=security-admin --as-group=platform-admins
echo ""
echo "dev-sales — создание deployments в sales (должно быть разрешено):"
kubectl auth can-i create deployments --as=dev-sales -n sales
echo ""
echo "dev-sales — доступ к secrets в sales (должен быть запрещён):"
kubectl auth can-i get secrets --as=dev-sales -n sales || true
echo ""
echo "dev-sales — чтение logs в sales (должно быть запрещено):"
if kubectl logs --as=dev-sales -n sales rbac-log-check-sales >/dev/null 2>&1; then
  echo "yes"
else
  echo "no"
fi
echo ""
echo "dev-sales — создание deployments в finance (должно быть запрещено):"
kubectl auth can-i create deployments --as=dev-sales -n finance || true
echo ""
echo "analyst-tenant — просмотр pods в tenant-services (должно быть разрешено):"
kubectl auth can-i get pods --as=analyst-tenant -n tenant-services
echo ""
echo "analyst-tenant — создание deployments в tenant-services (должно быть запрещено):"
kubectl auth can-i create deployments --as=analyst-tenant -n tenant-services || true
echo ""
echo "analyst-tenant — чтение logs в tenant-services (должно быть запрещено):"
if kubectl logs --as=analyst-tenant -n tenant-services rbac-log-check-tenant >/dev/null 2>&1; then
  echo "yes"
else
  echo "no"
fi
echo ""
echo "analyst-tenant — просмотр pods в sales (должно быть запрещено):"
kubectl auth can-i get pods --as=analyst-tenant -n sales || true

kubectl delete pod rbac-log-check-sales -n sales --ignore-not-found --wait=false >/dev/null 2>&1 || true
kubectl delete pod rbac-log-check-tenant -n tenant-services --ignore-not-found --wait=false >/dev/null 2>&1 || true
