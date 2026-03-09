#!/bin/bash
set -euo pipefail

echo "=== Развёртывание 4 сервисов (nginx) с метками ==="
echo ""

kubectl run front-end-app --image=nginx --labels role=front-end --expose --port 80
echo "--- front-end-app (role=front-end) создан ---"

kubectl run back-end-api-app --image=nginx --labels role=back-end-api --expose --port 80
echo "--- back-end-api-app (role=back-end-api) создан ---"

kubectl run admin-front-end-app --image=nginx --labels role=admin-front-end --expose --port 80
echo "--- admin-front-end-app (role=admin-front-end) создан ---"

kubectl run admin-back-end-api-app --image=nginx --labels role=admin-back-end-api --expose --port 80
echo "--- admin-back-end-api-app (role=admin-back-end-api) создан ---"

echo ""
echo "=== Ожидание готовности pod'ов ==="
kubectl wait --for=condition=Ready pod/front-end-app pod/back-end-api-app pod/admin-front-end-app pod/admin-back-end-api-app --timeout=120s

echo ""
echo "=== Все сервисы развёрнуты ==="
echo ""
echo "Pods:"
kubectl get pods -o wide --show-labels
echo ""
echo "Services:"
kubectl get svc
