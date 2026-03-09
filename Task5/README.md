# Задание 5. Управление трафиком внутри кластера Kubernetes

## Обоснование

В задании 1 утечка и искажение данных оценены как критические риски. В задании 2 (п. III.2) зафиксировано отсутствие сегментации сети между логическими зонами, фильтрация трафика между сегментами (п. III.11) не подтверждена. В задании 3 smart-home-gateway должен быть изолирован в отдельном сетевом сегменте и доступен только из tenant-core-app.

Task4 ограничил плоскость управления кластером (RBAC -- кто может менять ресурсы). Task5 ограничивает плоскость данных -- какие pod'ы могут общаться по сети.

Четыре nginx-сервиса развёрнуты в одном namespace с метками `role`:

| Pod | Метка | Пара |
| --- | --- | --- |
| front-end-app | role=front-end | front-end <-> back-end-api |
| back-end-api-app | role=back-end-api | front-end <-> back-end-api |
| admin-front-end-app | role=admin-front-end | admin-front-end <-> admin-back-end-api |
| admin-back-end-api-app | role=admin-back-end-api | admin-front-end <-> admin-back-end-api |

Сетевые политики в `network-policies.yaml` (6 документов):
- `default-deny-all` -- запрещает весь ingress и egress для всех pod'ов
- `allow-dns` -- разрешает egress к kube-dns (порт 53 UDP/TCP) для резолвинга имён сервисов
- `allow-front-end` -- ingress от back-end-api, egress к back-end-api (TCP/80)
- `allow-back-end-api` -- ingress от front-end, egress к front-end (TCP/80)
- `allow-admin-front-end` -- ingress от admin-back-end-api, egress к admin-back-end-api (TCP/80)
- `allow-admin-back-end-api` -- ingress от admin-front-end, egress к admin-front-end (TCP/80)

Трафик между непарными сервисами запрещён default-deny-all.

## Файлы

| Файл | Что делает |
| --- | --- |
| `deploy-services.sh` | Создаёт 4 pod'а (nginx) с метками и Service через `kubectl run --expose --port 80`. Ждёт Ready. |
| `network-policies.yaml` | 6 NetworkPolicy: default-deny-all, allow-dns, по одной allow-политике на каждый pod с разрешением трафика только к парному партнёру на TCP/80. |
| `verify.sh` | 8 проверок: 4 разрешённых соединения (front-end <-> back-end-api, admin-front-end <-> admin-back-end-api) и 4 запрещённых кросс-соединения. Запускает test-pod с нужной меткой, делает `wget --timeout=2`. |

## Порядок запуска

```
minikube start --cni calico
./deploy-services.sh
kubectl apply -f network-policies.yaml
./verify.sh
```

Calico обязателен -- vanilla minikube (kindnet) не применяет NetworkPolicy.
