# Задание 7. Политики безопасности контейнеров (PodSecurity + OPA Gatekeeper)

## Обоснование

В Задании 6 (`analysis.md`, п. 2-3) зафиксировано: нет admission control и нет PodSecurity -- привилегированный pod создаётся без ограничений. Задания 4-5 закрыли RBAC и сетевую изоляцию, Задание 6 добавило аудит. Задание 7 добавляет preventive control на уровне pod spec.

Два слоя нужны потому, что встроенный PSA `restricted` не проверяет `readOnlyRootFilesystem` (помечен как "no opinion" в Pod Security Standards). PSA покрывает privileged, hostPath, runAsNonRoot, seccomp, capabilities. Gatekeeper добирает `readOnlyRootFilesystem` и даёт CRD-based политики, которые сами аудируются.

## Порядок запуска

```
minikube stop 2>/dev/null || true

mkdir -p ~/.minikube/files/etc/ssl/certs
cp Task7/audit-policy.yaml ~/.minikube/files/etc/ssl/certs/audit-policy.yaml

minikube start \
  --extra-config=apiserver.audit-policy-file=/etc/ssl/certs/audit-policy.yaml \
  --extra-config=apiserver.audit-log-path=/var/log/audit.log

kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.21.1/deploy/gatekeeper.yaml
kubectl -n gatekeeper-system wait pod --all --for=condition=Ready --timeout=90s

kubectl apply -f Task7/01-create-namespace.yaml
kubectl apply -f Task7/gatekeeper/constraint-templates/
sleep 5
kubectl apply -f Task7/gatekeeper/constraints/

bash Task7/verify/verify-admission.sh
bash Task7/verify/validate-security.sh
```

Пауза между templates и constraints нужна -- Gatekeeper регистрирует CRD асинхронно.

## Ожидаемые результаты

| Манифест | Результат | Кто блокирует |
|---|---|---|
| insecure-manifests/01-privileged-pod.yaml | Rejected | PSA + Gatekeeper |
| insecure-manifests/02-hostpath-pod.yaml | Rejected | PSA + Gatekeeper |
| insecure-manifests/03-root-user-pod.yaml | Rejected | PSA + Gatekeeper |
| secure-manifests/01-secure.yaml | Admitted | -- |
| secure-manifests/02-secure.yaml | Admitted | -- |
| secure-manifests/03-secure.yaml | Admitted | -- |
| test-gatekeeper-only (validate-security.sh) | Rejected | Gatekeeper only |

Insecure manifests отклоняются по нескольким причинам сразу -- `restricted` кумулятивен, API server перечисляет все несоответствия (seccomp, capabilities и т. д.), а не только целевое.

`test-gatekeeper-only` проходит PSA `restricted`, но не имеет `readOnlyRootFilesystem: true`. PSA пропускает, Gatekeeper отклоняет.

## Нюансы

Стандартный `nginx` запускается от root и пишет в rootfs. В secure-manifests используется `nginxinc/nginx-unprivileged` (UID 101, порт 8080) с `emptyDir` на `/tmp`, `/var/cache/nginx`, `/var/run`.

В задании 4 правила Gatekeeper, но в примере дерева файлов -- 3 пары. Добавлена четвёртая пара `readonlyrootfs.yaml`, потому что это единственное правило, которое PSA не покрывает.

## Файлы

| Файл | Что делает |
|---|---|
| `01-create-namespace.yaml` | Namespace `audit-zone` с labels PSA restricted (enforce + warn + audit) |
| `insecure-manifests/01-privileged-pod.yaml` | Pod с `privileged: true` |
| `insecure-manifests/02-hostpath-pod.yaml` | Pod с `hostPath` volume |
| `insecure-manifests/03-root-user-pod.yaml` | Pod с `runAsUser: 0` |
| `secure-manifests/0{1,2,3}-secure.yaml` | Безопасные pod'ы (nginxinc/nginx-unprivileged, полный restricted securityContext, emptyDir для writable paths) |
| `gatekeeper/constraint-templates/*.yaml` | 4 ConstraintTemplate: privileged, hostpath, runasnonroot, readonlyrootfs |
| `gatekeeper/constraints/*.yaml` | 4 Constraint, ограниченные namespace `audit-zone` |
| `verify/verify-admission.sh` | 6 проверок: 3 insecure отклоняются, 3 secure проходят |
| `verify/validate-security.sh` | Проверка: pod без readOnlyRootFilesystem отклоняется Gatekeeper (PSA пропускает) |
| `audit-policy.yaml` | RequestResponse для pods, Gatekeeper CRDs, namespaces. Metadata для остальных. |
