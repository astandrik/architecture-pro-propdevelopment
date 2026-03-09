#!/bin/bash
set -euo pipefail

CERTS_DIR="./certs"
mkdir -p "${CERTS_DIR}"

CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_CA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority}')

if [ -z "${CLUSTER_CA}" ] || [ "${CLUSTER_CA}" = "null" ]; then
  CLUSTER_CA_DATA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
  echo "${CLUSTER_CA_DATA}" | base64 -d > "${CERTS_DIR}/ca.crt"
  CLUSTER_CA="${CERTS_DIR}/ca.crt"
fi

create_user() {
  local USERNAME=$1
  local GROUP=$2
  local NAMESPACE=${3:-}
  local CONTEXT_NAME="${USERNAME}-context"

  echo "=== Создание пользователя: ${USERNAME} (группа: ${GROUP}) ==="

  openssl genrsa -out "${CERTS_DIR}/${USERNAME}.key" 2048 2>/dev/null

  openssl req -new \
    -key "${CERTS_DIR}/${USERNAME}.key" \
    -out "${CERTS_DIR}/${USERNAME}.csr" \
    -subj "/CN=${USERNAME}/O=${GROUP}"

  CSR_BASE64=$(cat "${CERTS_DIR}/${USERNAME}.csr" | base64 | tr -d '\n')

  kubectl delete csr "${USERNAME}" 2>/dev/null || true

  cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USERNAME}
spec:
  request: ${CSR_BASE64}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
    - client auth
EOF

  kubectl certificate approve "${USERNAME}"

  kubectl get csr "${USERNAME}" -o jsonpath='{.status.certificate}' | \
    base64 -d > "${CERTS_DIR}/${USERNAME}.crt"

  kubectl config set-credentials "${USERNAME}" \
    --client-certificate="${CERTS_DIR}/${USERNAME}.crt" \
    --client-key="${CERTS_DIR}/${USERNAME}.key"

  if [ -n "${NAMESPACE}" ]; then
    kubectl config set-context "${CONTEXT_NAME}" \
      --cluster="${CLUSTER_NAME}" \
      --user="${USERNAME}" \
      --namespace="${NAMESPACE}"
  else
    kubectl config set-context "${CONTEXT_NAME}" \
      --cluster="${CLUSTER_NAME}" \
      --user="${USERNAME}"
  fi

  echo "--- Пользователь ${USERNAME} создан, контекст: ${CONTEXT_NAME} ---"
  echo ""
}

# ИБ-специалист — привилегированная группа (cluster-admin)
create_user "security-admin" "platform-admins"

# Разработчик домена продаж — группа конфигурации (namespace-admin)
create_user "dev-sales" "developers" "sales"

# Бизнес-аналитик домена ЖКУ — группа просмотра (namespace-viewer)
create_user "analyst-tenant" "viewers" "tenant-services"

echo "=== Все пользователи созданы ==="
echo "Сертификаты сохранены в ${CERTS_DIR}/"
echo ""
echo "Доступные контексты:"
kubectl config get-contexts
