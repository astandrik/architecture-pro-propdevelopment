# Таблица ролей Kubernetes для PropDevelopment

## Namespaces

- `sales` -- сервисы продаж (витрина, client-tour-app, client-mart-app, client-crm-app, client-mart-estate-app)
- `tenant-services` -- сервисы ЖКУ (витрина, tenant-core-app, CRM, smart-home-gateway)
- `finance` -- финансы (accountant-service-1, БД, служба каталогов)
- `data-processing` -- обработка данных (хранилище, BI, отчётность)

## Роли

| Роль | Права роли | Группы пользователей |
| --- | --- | --- |
| `cluster-admin` (встроенная ClusterRole) | Все verbs на все ресурсы во всех namespaces, включая `secrets`, `roles`, `rolebindings`, `nodes`, `namespaces`, `persistentvolumes`. Привязка через ClusterRoleBinding -- на весь кластер. | `platform-admins`: DevOps-инженеры и ИБ-специалист. |
| `namespace-admin` (ClusterRole) | `get`, `list`, `watch`, `create`, `update`, `patch`, `delete` на `pods`, `deployments`, `replicasets`, `statefulsets`, `services`, `configmaps`, `ingresses`, `persistentvolumeclaims`, `serviceaccounts`, `events`, `pods/log`. Без доступа к `secrets`, ресурсам RBAC, `nodes`, `namespaces`, `persistentvolumes`. Привязка через RoleBinding конкретного пользователя в namespace его домена. | `developers`: разработчики и инженеры по эксплуатации. Каждый пользователь привязан к namespace своего домена. |
| `namespace-viewer` (ClusterRole) | `get`, `list`, `watch` на `pods`, `deployments`, `replicasets`, `statefulsets`, `services`, `configmaps`, `ingresses`, `persistentvolumeclaims`, `events`, `pods/log`. Без `secrets`, без мутирующих операций. Привязка через RoleBinding конкретного пользователя в namespace его домена. | `viewers`: бизнес-аналитики, владельцы продуктов, менеджеры операционных команд. Каждый пользователь привязан к namespace своего домена. |
