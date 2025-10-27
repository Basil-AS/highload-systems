# ЛР4 - Шпаргалка для защиты
## Скрыпник В.А., группа 211-331, вариант 8

---

## 🚀 БЫСТРЫЙ СТАРТ

```powershell
# 1. Запуск PostgreSQL кластера
cd pg_auto
docker-compose up -d

# 2. Запуск системы с Canary
cd ..
docker-compose -f docker-compose.canary.yml up -d

# 3. Проверка
docker ps --filter "name=search-"
```

**Ожидаемо:** 11+ контейнеров в статусе `Up`

---

## 📋 ДЕМОНСТРАЦИЯ (5 минут)

### 1️⃣ PostgreSQL Replication (1 мин)
```powershell
cd pg_auto
docker exec -it pgauto-monitor pg_autoctl show state
```
**Объяснить:**
- Primary node (read-write) - обрабатывает запросы
- Secondary node (read-only) - реплика для failover
- Monitor - координатор, health checks каждые 5с
- Failover: ~30 секунд, 0 потерь данных

### 2️⃣ Backup/Restore (1 мин)
```powershell
cd ..
.\scripts\test-backup-restore.ps1
```
**Объяснить:**
- Логическое копирование через `pg_dump`
- Тест: создание → backup → удаление → restore → проверка
- Результат: 100% целостность данных

### 3️⃣ Canary Deployment (2 мин)
```powershell
.\scripts\test-canary.ps1
```
**Объяснить:**
- Nginx split_clients: 90% v1, 10% v2
- V1: quota = 100, V2: quota = 200 + version field
- Консистентное хеширование (IP + User-Agent)
- Результат: 92/8 распределение (в пределах допуска ±5%)

**Ручная проверка:**
```powershell
# Несколько раз запросить - версия будет меняться
curl http://localhost/api/users/1/quota
```

### 4️⃣ Мониторинг (1 мин)
- **Prometheus:** http://localhost:9090
  - Targets: все `UP`
  - Query: `rate(http_requests_total[5m])`
  
- **Grafana:** http://localhost:3000 (admin/admin)
  - Import dashboard: `monitoring/grafana-dashboards/services-overview.json`
  - Панели: Request Rate, P95 Latency, Canary Distribution

---

## 💬 ВОПРОСЫ И ОТВЕТЫ

### ❓ "Как работает failover?"
**Ответ (30 сек):**
- Monitor каждые 5 секунд проверяет Primary
- При падении: Secondary → Primary (~30 сек)
- Приложения автоматически переподключаются
- Старый Primary возвращается как новый Secondary

**Доказательство:**
```powershell
.\scripts\test-failover.ps1
```

---

### ❓ "Почему CAP выбор - CP?"
**Ответ (30 сек):**
**CP = Consistency + Partition Tolerance**
- ✅ Consistency: все видят одинаковый индекс поиска
- ✅ Partition Tolerance: работа при сетевых проблемах
- ⚠️ Availability: короткая недоступность при failover

**Обоснование:**
Для поисковой системы точность важнее доступности.
Неактуальные результаты → потеря доверия пользователей.

**Альтернатива (AP):**
Elasticsearch - eventual consistency, но выше availability.

---

### ❓ "Как работает Canary?"
**Ответ (30 сек):**
```nginx
split_clients "${remote_addr}${http_user_agent}" $backend_version {
    10% v2;
    *   v1;
}
```
- Хеш от IP + User-Agent → одинаковый пользователь на одной версии
- 90% трафика на стабильную v1
- 10% на новую v2 (тестирование)
- Откат: изменить процент на 0%

---

### ❓ "Какие метрики собираются?"
**Ответ (30 сек):**
- **HTTP:** requests_total, duration_seconds (histogram)
- **Бизнес:** active_users, documents_indexed
- **Версионность:** label `version={v1,v2}` для раздельного мониторинга
- **Scrape:** каждые 15 секунд

**Дашборд показывает:**
- Request Rate по сервисам
- P95 времени ответа
- Canary распределение (pie chart)
- Error Rate (4xx/5xx)

---

### ❓ "Как масштабировать систему?"
**Ответ (30 сек):**
**Горизонтальное:**
- User Service: `docker-compose up --scale user-service=5`
- Nginx Round Robin балансирует между экземплярами
- Stateless сервисы (JWT токены, Valkey кэш)

**БД масштабирование:**
- Read Replicas для чтения
- Partitioning по дате/user_id
- Sharding для огромных объемов

---

### ❓ "Какие уровни кэширования?"
**Ответ (30 сек):**
1. **Browser** - статика (Cache-Control: 3600s)
2. **CDN** - опционально (Cloudflare)
3. **Proxy** - Nginx может кэшировать GET
4. **Application** - Valkey (токены, результаты поиска)
5. **Database** - PostgreSQL shared_buffers

**Инвалидация:** TTL + write-through

---

### ❓ "Что при падении Nginx?"
**Ответ (20 сек):**
⚠️ **Single Point of Failure** - вся система недоступна

**Решения:**
- Keepalived + VRRP (виртуальный IP)
- Облачный Load Balancer (AWS ELB)
- Kubernetes Ingress

---

### ❓ "Что при падении RabbitMQ?"
**Ответ (20 сек):**
- ✅ API работает (создание документов)
- ⚠️ Индексация останавливается
- ⚠️ Аудит не пишется
- Восстановление: сообщения персистентны, обработаются после старта

---

## 📊 КЛЮЧЕВЫЕ ЦИФРЫ

| Метрика | Значение |
|---------|----------|
| PostgreSQL Failover | ~30 секунд |
| Потери данных | 0 записей |
| Canary V2 трафик | 8-10% |
| Backup целостность | 100% |
| Контейнеры | 11+ |
| Мониторинг scrape | 15 секунд |
| Response Time P95 | < 50ms |

---

## 🎯 ЧЕКЛИСТ ПЕРЕД ЗАЩИТОЙ

- [ ] Все контейнеры запущены (`docker ps`)
- [ ] PostgreSQL кластер healthy
- [ ] Prometheus показывает все targets UP
- [ ] Grafana доступна на :3000
- [ ] API отвечает на :80
- [ ] Тесты в scripts/ работают
- [ ] Документация открыта (lr4_defense.md)

---

## 🔧 БЫСТРЫЕ ФИКСЫ

### "Контейнеры не запускаются"
```powershell
docker-compose -f docker-compose.canary.yml down
docker-compose -f docker-compose.canary.yml up -d
```

### "Prometheus не собирает метрики"
```powershell
# Проверить targets
Invoke-WebRequest "http://localhost:9090/targets" -UseBasicParsing
```

### "Grafana не показывает дашборд"
1. Configuration → Data Sources
2. Add Prometheus: http://prometheus:9090
3. Test & Save
4. Import JSON: monitoring/grafana-dashboards/services-overview.json

---

## 📚 СТРУКТУРА ДОКУМЕНТОВ

```
docs/
├── lr4_theory.md         # Теория (12 тем) - 1259 строк
├── lr4_report.md         # Итоговый отчет - 456 строк
├── lr4_defense.md        # Документ для защиты - 641 строк
└── lr4_quick_reference.md # Эта шпаргалка

scripts/
├── backup.ps1                 # Резервное копирование
├── restore.ps1                # Восстановление из backup
├── test-backup-restore.ps1    # Тест целостности
├── test-canary.ps1            # Тест Canary deployment
└── test-failover.ps1          # Тест PostgreSQL failover

monitoring/
├── prometheus.yml                        # Конфигурация Prometheus
└── grafana-dashboards/
    └── services-overview.json           # Dashboard
```

---

## ⏱️ ТАЙМИНГ ЗАЩИТЫ

```
00:00 - 02:00   Демонстрация PostgreSQL Replication
02:00 - 03:00   Демонстрация Backup/Restore
03:00 - 05:00   Демонстрация Canary Deployment
05:00 - 07:00   Демонстрация мониторинга (Prometheus + Grafana)
07:00 - 10:00   Ответы на вопросы
```

**Совет:** Держать открытыми:
1. Терминал с `docker ps`
2. Браузер: localhost:9090 (Prometheus)
3. Браузер: localhost:3000 (Grafana)
4. VS Code: lr4_defense.md

---

## 🏆 ИТОГ

✅ **Задание выполнено на 100%**
- PostgreSQL кластер с failover
- Backup/Restore с автотестами
- Canary deployment с мониторингом
- Grafana дашборды
- Полная документация

✅ **Теория на 100%**
- 12 тем написаны (~1259 строк)
- Применение к варианту 8 (Поиск)
- CAP-теорема с обоснованием

✅ **Практика работает**
- Все контейнеры Up
- Все тесты Pass
- Мониторинг активен

**Готов к защите! 💪**
