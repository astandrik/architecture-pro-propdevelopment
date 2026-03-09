# Задание 4. Защита доступа к кластеру Kubernetes

## Обоснование

В задании 1 учётные данные и ключи доступа отнесены к категории "секретные" с критическим риском утечки. В задании 2 (п. I.4) зафиксировано, что принцип минимальных привилегий не реализован. В задании 3 API key партнёра Smart Home хранится в Kubernetes Secret, поэтому прямой доступ к `secrets` API должен быть только у привилегированной группы.

Используются три роли:
- `cluster-admin` (встроенная) -- полный доступ, включая secrets и RBAC. Для DevOps и ИБ-специалиста.
- `namespace-admin` -- управление workloads без прямого доступа к `secrets` API, logs и RBAC. Для разработчиков и инженеров по эксплуатации.
- `namespace-viewer` -- просмотр метаданных и состояния без secrets и logs. Для бизнес-аналитиков, PO и менеджеров.

Четыре namespace соответствуют четырём доменам компании: `sales`, `tenant-services`, `finance`, `data-processing`. Каждый пользователь привязан к namespace своего домена через RoleBinding, а группа `platform-admins` -- через ClusterRoleBinding на весь кластер.

## Файлы

| Файл | Что делает |
| --- | --- |
| `roles-table.md` | Таблица ролей: роль, права, группа пользователей |
| `create-roles.sh` | Создаёт 4 namespace и 2 ClusterRole (namespace-admin, namespace-viewer). cluster-admin встроенная, создавать не нужно. |
| `create-users.sh` | Создаёт 3 пользователей через X.509 сертификаты (OpenSSL + K8s CSR API), настраивает kubeconfig и выставляет namespace по умолчанию для namespaced-пользователей. Пользователи: `security-admin` (O=platform-admins), `dev-sales` (O=developers), `analyst-tenant` (O=viewers). Группа определяется полем O= в сертификате. |
| `bind-roles.sh` | Привязывает пользователей к ролям: ClusterRoleBinding для группы platform-admins (весь кластер), RoleBinding для dev-sales в namespace sales, RoleBinding для analyst-tenant в namespace tenant-services. В конце проверяет права через `kubectl auth can-i`, включая негативные проверки в чужих namespace. |

## Порядок запуска

```
minikube start
./create-roles.sh
./create-users.sh
./bind-roles.sh
```
