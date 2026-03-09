# Отчёт по результатам анализа Kubernetes Audit Log

## Подозрительные события

1. Доступ к секретам:
   - Кто: `minikube-user` через impersonation от имени `system:serviceaccount:secure-ops:monitoring`
   - Где: namespace `kube-system`, ресурс `secrets` (verb: `list`, код ответа: 403 Forbidden)
   - Почему подозрительно: SA `monitoring` из `secure-ops` пытается получить список секретов в `kube-system`. Прав у него нет — API server вернул 403. Перед этим выполнена проверка прав через `SelfSubjectAccessReview` (`kubectl auth can-i`) — типичная разведка перед эскалацией. В RBAC-модели из Task4 доступ к secrets есть только у группы `platform-admins`, роли `namespace-admin` и `namespace-viewer` secrets исключают.

2. Привилегированные поды:
   - Кто: `minikube-user`
   - Комментарий: создан pod `privileged-pod` в `secure-ops` (201 Created) с `securityContext.privileged: true`. Такой контейнер имеет полный доступ к хостовой ОС — монтирование файловых систем ноды, чтение `/etc/shadow`, управление сетевыми интерфейсами. Из привилегированного пода можно получить root на ноде.

3. Использование kubectl exec в чужом поде:
   - Кто: `minikube-user`
   - Что делал: выполнил `cat /etc/resolv.conf` в поде `coredns-66bc5c9577-wpz4x` в `kube-system` (101 Switching Protocols — WebSocket для exec установлен). CoreDNS — системный компонент. Выполнение команд в таких подах даёт доступ к внутренней конфигурации кластера и сетевым привилегиям пода.

4. Создание RoleBinding с правами cluster-admin:
   - Кто: `minikube-user` (201 Created)
   - К чему привело: SA `monitoring` в `secure-ops` получил привязку к ClusterRole `cluster-admin` через RoleBinding `escalate-binding`. В audit event это подтверждается полем `requestObject.roleRef`: `kind = ClusterRole`, `name = cluster-admin`. В рамках namespace SA теперь имеет полный доступ ко всем ресурсам, включая secrets и RBAC-объекты. В RBAC-модели из Task4 такие привязки делаются только группой `platform-admins` через ClusterRoleBinding.

5. Удаление audit-policy.yaml:
   - Кто: в `audit.log` не зафиксировано — API-запроса не было
   - Возможные последствия: команда `kubectl delete -f /etc/kubernetes/audit-policy.yaml --as=admin` завершилась локально с ошибкой `the path "/etc/kubernetes/audit-policy.yaml" does not exist`. kubectl не отправил запрос в API server, поэтому в audit.log события нет. В production-среде, где файл доступен, такое действие означало бы попытку отключить журналирование.

## Вывод

### Кто инициировал действия

Подтверждённые события инициированы от имени `minikube-user` (группа `system:masters`). В действии 1 использован impersonation `--as=system:serviceaccount:secure-ops:monitoring`. Действие 5 в audit.log не попало.

### Какие действия вредоносны

Действия составляют цепочку атаки:
- Проверка прав и попытка чтения секретов — разведка
- Привилегированный pod — эскалация до root на ноде
- exec в CoreDNS — lateral movement
- Попытка удаления audit-policy — антифорензика
- RoleBinding на cluster-admin — эскалация привилегий и закрепление

### Что считать компрометацией кластера

- Привилегированный под (201) — root-доступ к хостовой ОС ноды
- RoleBinding `escalate-binding` (201) — полный контроль над namespace `secure-ops`
- exec в CoreDNS (101) — доступ к системному компоненту control plane

### Ошибки политики RBAC

1. Нет ограничений на impersonation. Пользователь с правами admin может выполнять запросы от имени любых SA через `--as`. Нужны RBAC-правила на verb `impersonate`.
2. Нет ограничений на создание RoleBinding к cluster-admin. API server разрешил привязку без валидации. Нужна политика admission control (OPA Gatekeeper / Kyverno).
3. Нет PodSecurity. Namespace `secure-ops` без label `pod-security.kubernetes.io/enforce` — привилегированный под создаётся без ограничений.
4. SA `monitoring` создан без ограничения прав. После привязки к cluster-admin получил полный доступ в namespace.
