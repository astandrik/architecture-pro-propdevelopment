#!/bin/bash
set -euo pipefail

echo "=== Создание namespaces (домены PropDevelopment) ==="

kubectl create namespace sales --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace tenant-services --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace finance --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace data-processing --dry-run=client -o yaml | kubectl apply -f -

echo "--- Namespaces созданы ---"
echo ""

echo "=== Создание ClusterRole: namespace-admin ==="

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-admin
rules:
  - apiGroups: [""]
    resources:
      - pods
      - services
      - configmaps
      - persistentvolumeclaims
      - serviceaccounts
      - events
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources:
      - deployments
      - replicasets
      - statefulsets
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["networking.k8s.io"]
    resources:
      - ingresses
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

echo "--- ClusterRole namespace-admin создана ---"
echo ""

echo "=== Создание ClusterRole: namespace-viewer ==="

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-viewer
rules:
  - apiGroups: [""]
    resources:
      - pods
      - services
      - configmaps
      - persistentvolumeclaims
      - events
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources:
      - deployments
      - replicasets
      - statefulsets
    verbs: ["get", "list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources:
      - ingresses
    verbs: ["get", "list", "watch"]
EOF

echo "--- ClusterRole namespace-viewer создана ---"
echo ""

echo "=== Роли созданы. cluster-admin — встроенная, создавать не нужно ==="
echo ""
echo "Итого ClusterRoles:"
kubectl get clusterroles namespace-admin namespace-viewer cluster-admin --no-headers
