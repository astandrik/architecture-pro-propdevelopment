#!/usr/bin/env node

const fs = require('fs');

const AUDIT_LOG = process.argv[2] || 'audit.log';
const OUTPUT = process.argv[3] || 'audit-extract.json';

if (!fs.existsSync(AUDIT_LOG)) {
  console.error(`Файл ${AUDIT_LOG} не найден.`);
  console.error('Извлеките его из minikube:');
  console.error('  CONTAINER=$(minikube ssh -- "docker ps --filter=name=k8s_kube-apiserver --format \'{{.ID}}\'")');
  console.error('  minikube ssh -- "docker cp ${CONTAINER}:/var/log/audit.log /tmp/audit.log"');
  console.error('  minikube cp minikube:/tmp/audit.log audit.log');
  process.exit(1);
}

const SYSTEM_USER_RE = /^(system:|kubernetes-admin|minikube$)/;
const MONITORING_SA = 'system:serviceaccount:secure-ops:monitoring';

const filters = [
  {
    name: 'доступ к secrets (impersonation от monitoring SA)',
    match: (e) =>
      e.stage === 'ResponseComplete' &&
      e.impersonatedUser?.username === MONITORING_SA &&
      (e.objectRef?.resource === 'secrets' ||
       e.objectRef?.resource === 'selfsubjectaccessreviews'),
  },
  {
    name: 'привилегированные поды',
    match: (e) =>
      e.stage === 'ResponseComplete' &&
      e.verb === 'create' &&
      e.objectRef?.resource === 'pods' &&
      e.requestObject?.spec?.containers?.[0]?.securityContext?.privileged === true &&
      !SYSTEM_USER_RE.test(e.user?.username || ''),
  },
  {
    name: 'kubectl exec в чужие поды',
    match: (e) =>
      e.stage === 'ResponseComplete' &&
      e.objectRef?.subresource === 'exec',
  },
  {
    name: 'удаление audit-policy (impersonation --as=admin)',
    match: (e) =>
      e.stage === 'ResponseComplete' &&
      e.impersonatedUser?.username === 'admin',
  },
  {
    name: 'RoleBinding с cluster-admin (от не-системных пользователей)',
    match: (e) =>
      e.stage === 'ResponseComplete' &&
      e.objectRef?.resource === 'rolebindings' &&
      (e.verb === 'create' || e.verb === 'patch') &&
      e.requestObject?.roleRef?.name === 'cluster-admin' &&
      !SYSTEM_USER_RE.test(e.user?.username || ''),
  },
];

const lines = fs.readFileSync(AUDIT_LOG, 'utf-8').split('\n').filter(Boolean);

const events = [];
for (const line of lines) {
  try {
    events.push(JSON.parse(line));
  } catch {}
}

console.log(`=== Фильтрация подозрительных событий из ${AUDIT_LOG} ===`);
console.log(`    Всего событий в логе: ${events.length}`);
console.log('');

const matched = new Map();

for (const filter of filters) {
  const hits = events.filter(filter.match);
  console.log(`--- Фильтр: ${filter.name} ---`);
  console.log(`    Найдено: ${hits.length} событий`);

  if (filter.name.includes('audit-policy') && hits.length === 0) {
    console.log('    (команда kubectl delete -f ... --as=admin завершилась до отправки API-запроса: файл не найден на хосте)');
  }

  for (const hit of hits) {
    if (!matched.has(hit.auditID)) {
      matched.set(hit.auditID, hit);
    }
  }
}

const result = [...matched.values()];

console.log('');
console.log(`=== Объединение и дедупликация по auditID ===`);
console.log(`    Итого уникальных событий: ${result.length}`);

fs.writeFileSync(OUTPUT, JSON.stringify(result, null, 2));
console.log(`=== Результат записан в ${OUTPUT} ===`);
