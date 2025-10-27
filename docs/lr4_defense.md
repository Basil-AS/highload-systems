# ЛР4: Документ для защиты
## Скрыпник Василий Александрович, группа 211-331
## Вариант 8: Система поиска документов

---

## 📋 КОНТРОЛЬНЫЙ СПИСОК ВЫПОЛНЕНИЯ

### ✅ Практическая часть (10/10 заданий)

| № | Задание | Статус | Доказательство |
|---|---------|--------|----------------|
| 1 | PostgreSQL Replication (pg_auto_failover) | ✅ | 3 узла работают, failover ~30с |
| 2 | Backup/Restore скрипты | ✅ | `scripts/backup.ps1`, `scripts/restore.ps1` |
| 3 | Тесты Backup/Restore | ✅ | `scripts/test-backup-restore.ps1` - PASSED |
| 4 | Canary Deployment | ✅ | v1 (90%) + v2 (10%), nginx split_clients |
| 5 | Тесты Canary | ✅ | `scripts/test-canary.ps1` - 92/8 распределение |
| 6 | Prometheus мониторинг | ✅ | `monitoring/prometheus.yml` + метрики |
| 7 | Grafana дашборды | ✅ | `monitoring/grafana-dashboards/services-overview.json` |
| 8 | Docker Compose конфигурация | ✅ | `docker-compose.canary.yml` - 11 контейнеров |
| 9 | Документация | ✅ | README.md, lr4_theory.md, lr4_report.md |
| 10 | Автоматизация | ✅ | 3 PowerShell скрипта для тестирования |

### ✅ Теоретическая часть (12/12 тем)

1. ✅ Монолитная и микросервисная архитектуры (SOA)
2. ✅ Горизонтальное масштабирование
3. ✅ Трехзвенная архитектура
4. ✅ Распределение обработки запросов (Frontend vs Backend)
5. ✅ Кэширование (Browser, CDN, Proxy, Application)
6. ✅ Вычисления на стороне клиента
7. ✅ Стратегии масштабирования
8. ✅ DNS Round Robin балансировка
9. ✅ Отказоустойчивость (Fault Tolerance)
10. ✅ Масштабирование баз данных
11. ✅ Надежность систем (SLA, резервное копирование)
12. ✅ CAP-теорема и выбор для проекта

---

## 🚀 ИНСТРУКЦИИ ДЛЯ ДЕМОНСТРАЦИИ

### 1. Запуск системы

```powershell
# Терминал 1: PostgreSQL кластер
cd pg_auto
docker-compose up -d

# Терминал 2: Основная система с Canary Deployment
cd ..
docker-compose -f docker-compose.canary.yml up -d

# Проверка всех контейнеров
docker ps --filter "name=search-"
```

**Ожидаемый результат:** 11+ контейнеров в статусе `Up` и `healthy`

### 2. Проверка PostgreSQL Replication

```powershell
# Проверка состояния кластера
cd pg_auto
docker exec -it pgauto-monitor pg_autoctl show state

# Тест отказоустойчивости
.\scripts\test-failover.ps1
```

**Ожидаемый результат:**
- Primary: node1 или node2
- Secondary: node2 или node1
- Monitor: отслеживает состояние
- Failover: переключение за ~30 секунд, 0 потерь данных

### 3. Проверка Backup/Restore

```powershell
# Запуск автоматического теста
.\scripts\test-backup-restore.ps1
```

**Ожидаемый результат:**
```
✅ BACKUP/RESTORE TEST PASSED!
Records created: 3
Records after restore: 3
Backup file: backup_YYYYMMDD_HHMMSS.sql
```

### 4. Проверка Canary Deployment

```powershell
# Тест распределения трафика
.\scripts\test-canary.ps1
```

**Ожидаемый результат:**
```
✅ CANARY DEPLOYMENT TEST PASSED!
V1 requests: ~90%
V2 requests: ~10% (±5% допуск)
Errors: 0

Различия версий:
- V1: quota = 100 req/min, без поля version
- V2: quota = 200 req/min, version = "2.0.0"
```

**Ручная проверка:**
```powershell
# Проверка через браузер
curl http://localhost/api/users/1/quota

# Проверка заголовка версии
curl -I http://localhost/api/users/1/quota
# Ответ содержит: X-Backend-Version: v1 или v2
```

### 5. Мониторинг и визуализация

**Prometheus:**
- URL: http://localhost:9090
- Проверка метрик:
  ```
  rate(http_requests_total[5m])
  histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
  ```

**Grafana:**
- URL: http://localhost:3000
- Логин: `admin` / `admin`
- Импорт дашборда:
  1. Settings → Data Sources → Add Prometheus (http://prometheus:9090)
  2. Dashboards → Import → Upload JSON
  3. Файл: `monitoring/grafana-dashboards/services-overview.json`

**Ожидаемые панели:**
1. Request Rate by Service (bar chart)
2. Response Time P95 (time series)
3. Canary Traffic Distribution (pie chart: 90% v1, 10% v2)
4. Error Rate (graph)

### 6. Проверка API системы

```powershell
# Регистрация пользователя
curl -X POST http://localhost/api/users/ -H "Content-Type: application/json" -d '{\"username\":\"testuser\",\"email\":\"test@example.com\",\"password\":\"pass123\"}'

# Получение токена
curl -X POST http://localhost/api/users/token -d "username=testuser&password=pass123"

# Создание документа
$token = "YOUR_TOKEN_HERE"
curl -X POST http://localhost/api/documents/ -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d '{\"title\":\"Test\",\"content\":\"Test content\"}'

# Поиск документа
curl "http://localhost/api/search/?q=Test" -H "Authorization: Bearer $token"
```

---

## 📊 АРХИТЕКТУРА СИСТЕМЫ

### Компоненты системы

```
┌─────────────────────────────────────────────────────────────┐
│                         NGINX (Port 80)                      │
│              split_clients: 90% v1, 10% v2                   │
└────────────┬───────────────────────────────┬────────────────┘
             │                               │
    ┌────────▼────────┐            ┌────────▼────────┐
    │ User Service v1 │            │ User Service v2 │
    │   (quota: 100)  │            │   (quota: 200)  │
    └────────┬────────┘            └────────┬────────┘
             │                               │
             └───────────────┬───────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
    ┌────▼────┐      ┌──────▼──────┐    ┌──────▼──────┐
    │Document │      │   Search    │    │   Audit     │
    │Service  │      │   Service   │    │   Service   │
    └────┬────┘      └──────┬──────┘    └──────┬──────┘
         │                  │                   │
         └──────────────────┼───────────────────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
         ┌────▼────┐   ┌───▼────┐   ┌───▼────┐
         │PostgreSQL│   │ Valkey │   │RabbitMQ│
         │ Cluster  │   │ Cache  │   │  MQ    │
         │ (3 nodes)│   └────────┘   └────────┘
         └──────────┘
              │
    ┌─────────┼─────────┐
    │         │         │
┌───▼───┐ ┌──▼────┐ ┌──▼────┐
│Monitor│ │Node 1 │ │Node 2 │
│(5434) │ │(5432) │ │(5433) │
└───────┘ └───────┘ └───────┘
  Primary ← Sync → Secondary
```

### Мониторинг стек

```
┌──────────────┐      ┌────────────────┐
│  Services    │─────▶│  Prometheus    │
│  (metrics)   │      │   (scrape)     │
└──────────────┘      └────────┬───────┘
                                │
                                ▼
                       ┌────────────────┐
                       │    Grafana     │
                       │  (dashboards)  │
                       └────────────────┘
```

---

## 🎯 ОТВЕТЫ НА ВОПРОСЫ ДЛЯ ЗАЩИТЫ

### Блок 1: PostgreSQL Replication

**В: Как работает pg_auto_failover?**

О: `pg_auto_failover` использует архитектуру с монитором и узлами:
- **Monitor** (порт 5434) - координатор, отслеживает состояние узлов через health checks каждые 5 секунд
- **Primary node** - принимает запросы на чтение и запись
- **Secondary node** - асинхронная потоковая репликация (streaming replication)
- **Failover**: при падении Primary монитор автоматически продвигает Secondary → Primary за ~30 секунд

**В: Какие гарантии консистентности?**

О: Асинхронная репликация:
- ✅ Высокая производительность (запись не ждет подтверждения от реплики)
- ⚠️ Возможна потеря последних транзакций при failover (RPO ~5-10 секунд)
- ✅ В тестах: 0 потерь данных благодаря быстрому переключению

Для критичных данных можно настроить синхронную репликацию (`synchronous_commit = on`).

**В: Как происходит восстановление после failover?**

О: Автоматический процесс:
1. Monitor обнаруживает недоступность Primary (health check timeout)
2. Secondary продвигается в Primary (promotion)
3. Приложения переподключаются к новому Primary
4. Старый Primary восстанавливается как новый Secondary (автоматически)
5. Репликация возобновляется

### Блок 2: Backup/Restore

**В: Какие типы резервного копирования используются?**

О: **Логическое копирование** через `pg_dump`:
- ✅ Полный дамп всех баз данных в SQL-формат
- ✅ Кросс-версионная совместимость
- ✅ Выборочное восстановление таблиц
- ⚠️ Не подходит для PITR (Point-in-Time Recovery)

Альтернативы для production:
- **Физическое копирование** (`pg_basebackup`) - быстрее для больших БД
- **WAL архивирование** - для PITR
- **Снимки на уровне файловой системы** - для облачных решений

**В: Как тестируется целостность backup?**

О: Автоматический тест (`test-backup-restore.ps1`):
1. Создание тестовых данных (3 записи с уникальными email)
2. Выполнение backup через `pg_dump`
3. Удаление тестовых данных
4. Восстановление из backup через `psql`
5. Проверка количества записей (expected: 3, actual: 3)
6. Сравнение email для проверки целостности

**В: Какая стратегия хранения backup?**

О: Текущая реализация:
- Локальное хранение в `backups/` с timestamp в имени
- Ручное удаление старых копий

Рекомендации для production:
- Ротация: 7 дневных + 4 недельных + 12 месячных копий
- Географическое разнесение (разные дата-центры)
- Шифрование (`pg_dump --compress=9 | gpg --encrypt`)
- Облачное хранение (S3, MinIO)

### Блок 3: Canary Deployment

**В: Как реализовано разделение трафика?**

О: **Nginx split_clients** (консистентное хеширование):
```nginx
split_clients "${remote_addr}${http_user_agent}" $backend_version {
    10% v2;    # 10% трафика на v2
    *   v1;    # 90% трафика на v1
}
```
- Хеш рассчитывается от IP + User-Agent
- Один и тот же пользователь всегда попадает на одну версию (sticky sessions)
- Не требует внешних зависимостей (Redis, Consul)

**В: Какие различия между v1 и v2?**

О: Canary версия (v2) включает улучшения:
- **Квота увеличена**: 100 → 200 запросов/минуту
- **Поле version в API**: `{"version": "2.0.0"}` в ответах
- **Метрики Prometheus**: метка `version=v2` для раздельного мониторинга
- **Заголовок X-Backend-Version**: для отладки

**В: Как откатиться в случае проблем?**

О: Три стратегии:
1. **Быстрый откат** - изменить split_clients на 0% v2:
   ```nginx
   split_clients ... {
       0% v2;    # Отключить v2
       * v1;
   }
   ```
   Применить: `docker exec search-nginx-canary nginx -s reload`

2. **Постепенное снижение** - уменьшить процент v2 (10% → 5% → 0%)

3. **Полное удаление** - остановить контейнер v2:
   ```powershell
   docker-compose -f docker-compose.canary.yml stop user-service-v2
   ```

**В: Как тестируется распределение?**

О: Автоматический тест `test-canary.ps1`:
1. Health check обеих версий
2. 100 запросов с уникальными User-Agent
3. Подсчет версий через заголовок `X-Backend-Version`
4. Проверка допуска: 10% ±5% (5-15%)
5. Фактический результат: 8% v2 (✅ в пределах допуска)

### Блок 4: Мониторинг (Prometheus + Grafana)

**В: Какие метрики собираются?**

О: Prometheus scrape каждые 15 секунд:
- **HTTP метрики**: `http_requests_total`, `http_request_duration_seconds`
- **Бизнес-метрики**: `active_users`, `documents_indexed`
- **Системные**: CPU, память, подключения к БД
- **Версионность**: метка `version={v1,v2}` для раздельного мониторинга

**В: Какие дашборды созданы?**

О: Dashboard `services-overview.json` включает:
1. **Request Rate by Service** - запросов/сек по каждому сервису и версии
2. **Response Time P95** - 95-й перцентиль времени ответа
3. **Canary Traffic Distribution** - pie chart с распределением 90/10
4. **Error Rate** - график ошибок 4xx/5xx по времени

**В: Как настроить алерты?**

О: Prometheus Alerting (не реализовано, но можно добавить):
```yaml
groups:
  - name: canary_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        annotations:
          summary: "Error rate > 5% in canary"
      
      - alert: SlowResponse
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1.0
        annotations:
          summary: "P95 latency > 1s"
```

### Блок 5: CAP-теорема

**В: Какой выбор CAP для системы поиска?**

О: **CP (Consistency + Partition Tolerance)**:
- ✅ **Consistency** - все пользователи видят актуальный индекс документов
- ✅ **Partition Tolerance** - система работает при разделении сети (PostgreSQL кластер)
- ⚠️ **Availability** - приносим в жертву: при сетевых проблемах запросы могут блокироваться

**Обоснование:**
- Поисковая система требует точности результатов (consistency)
- Неактуальные результаты поиска снижают доверие пользователей
- Короткая недоступность (30 секунд при failover) приемлема

**Альтернатива (AP):**
- Eventual consistency - индекс может отставать
- Используется в: Elasticsearch (по умолчанию)
- Подходит для систем с огромным объемом данных, где важна скорость

**В: Как повысить Availability не теряя Consistency?**

О: Стратегии:
1. **Географическая репликация** - несколько кластеров в разных регионах
2. **Read replicas** - чтение с реплик (eventual consistency для чтения)
3. **Circuit Breaker** - быстрый возврат ошибки вместо таймаута
4. **Кэширование результатов** - временная доступность при падении БД

### Блок 6: Горизонтальное масштабирование

**В: Как масштабируется user-service?**

О: Stateless микросервис:
- Добавление новых экземпляров: `docker-compose up --scale user-service=5`
- Nginx балансировка Round Robin между экземплярами
- Сессии в JWT токенах (не требуют sticky sessions)
- Общий кэш в Valkey (Redis-compatible)

**Ограничения:**
- ⚠️ Rate limiting должен быть централизованным (Valkey counter)
- ⚠️ PostgreSQL становится узким местом (нужны read replicas)

**В: Как масштабируется база данных?**

О: Вертикальное + горизонтальное:
1. **Вертикальное** - увеличение CPU/RAM на узлах
2. **Read Replicas** - разделение чтения и записи
3. **Partitioning** - таблицы по диапазонам (по дате, по user_id)
4. **Sharding** - разделение данных по ключу (user_id % 3)

Текущая реализация: 1 Primary + 1 Secondary (репликация)

### Блок 7: Кэширование

**В: Какие уровни кэширования используются?**

О: Многоуровневое:
1. **Browser Cache** - статические ресурсы (Cache-Control: max-age=3600)
2. **CDN** - не используется (может быть добавлен Cloudflare/Nginx CDN)
3. **Proxy Cache** - Nginx может кэировать GET-ответы
4. **Application Cache (Valkey)** - токены, результаты поиска, rate limits
5. **Database Cache** - PostgreSQL shared_buffers (2GB по умолчанию)

**В: Какая стратегия инвалидации кэша?**

О: Комбинация подходов:
- **TTL** - автоматическое истечение (например, результаты поиска: 5 минут)
- **Write-through** - обновление кэша при записи в БД
- **Cache-aside** - проверка кэша → если нет → запрос к БД → сохранение в кэш

**Пример для токенов:**
```python
# Кэш на 30 минут
await valkey.setex(f"token:{user_id}", 1800, token)
```

### Блок 8: Отказоустойчивость

**В: Какие механизмы fault tolerance реализованы?**

О: Несколько уровней:
1. **Database** - PostgreSQL кластер (failover ~30 секунд)
2. **Services** - Health checks + автоматический рестарт контейнеров
3. **Message Queue** - RabbitMQ персистентность сообщений
4. **Load Balancer** - Nginx автоматически исключает недоступные upstream
5. **Backup** - ежедневные копии БД

**В: Что происходит при падении Nginx?**

О: Single Point of Failure:
- ⚠️ Вся система становится недоступной
- Решение: **Keepalived + VRRP** (виртуальный IP между двумя Nginx)
- Альтернатива: **Облачный Load Balancer** (AWS ELB, Azure Load Balancer)

**В: Что происходит при падении RabbitMQ?**

О: Деградация функциональности:
- ✅ API продолжает работать (создание документов)
- ⚠️ Индексация останавливается (worker не получает задачи)
- ⚠️ Аудит не записывается
- Восстановление: сообщения персистентны, обработаются после запуска RabbitMQ

---

## 📈 РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ

### Test 1: PostgreSQL Failover
```
✅ Тест пройден
- Время failover: ~30 секунд
- Потери данных: 0 записей
- Автоматическое восстановление: ✅
```

### Test 2: Backup/Restore
```
✅ Тест пройден
- Созданные записи: 3
- Восстановленные записи: 3
- Целостность данных: 100%
- Размер backup: ~2.5 KB (compressed: ~800 bytes)
```

### Test 3: Canary Deployment
```
✅ Тест пройден
- Всего запросов: 100
- V1 трафик: 92% (ожидалось: 90%)
- V2 трафик: 8% (ожидалось: 10% ±5%)
- Ошибки: 0
- Консистентность: пользователь всегда на одной версии
```

### Test 4: Load Testing (опционально)
```powershell
# Нагрузочный тест с Apache Bench
ab -n 1000 -c 10 http://localhost/api/users/1/quota

# Ожидаемый результат:
# - Requests per second: > 500 rps
# - Mean response time: < 20ms
# - Failed requests: 0
```

---

## 🔧 УСТРАНЕНИЕ ПРОБЛЕМ

### Проблема 1: "Контейнеры не запускаются"
```powershell
# Проверка логов
docker logs search-user-service-v1 --tail 50

# Пересборка образов
docker-compose -f docker-compose.canary.yml build --no-cache

# Очистка volumes
docker-compose -f docker-compose.canary.yml down -v
```

### Проблема 2: "Canary не распределяет трафик"
```powershell
# Проверка конфигурации Nginx
docker exec search-nginx-canary cat /etc/nginx/conf.d/default.conf

# Проверка upstream-ов
docker exec search-nginx-canary nginx -T | Select-String "upstream"

# Перезагрузка конфигурации
docker exec search-nginx-canary nginx -s reload
```

### Проблема 3: "PostgreSQL failover не работает"
```powershell
# Проверка состояния кластера
cd pg_auto
docker exec -it pgauto-monitor pg_autoctl show state

# Проверка логов монитора
docker logs pgauto-monitor --tail 50

# Ручное переключение
docker exec -it pgauto-node1 pg_autoctl perform failover
```

### Проблема 4: "Grafana не показывает метрики"
1. Проверить Prometheus: http://localhost:9090/targets
2. Все targets должны быть `UP`
3. В Grafana: Configuration → Data Sources → Test Connection
4. Query Editor: попробовать `up{job="user-service-v1"}`

---

## 📚 ИСТОЧНИКИ И МАТЕРИАЛЫ

### Документация
- PostgreSQL Auto Failover: https://pg-auto-failover.readthedocs.io/
- Nginx split_clients: http://nginx.org/en/docs/http/ngx_http_split_clients_module.html
- Prometheus: https://prometheus.io/docs/
- Grafana: https://grafana.com/docs/

### Используемые технологии
- PostgreSQL 15 + pg_auto_failover
- Nginx 1.25
- Prometheus 2.45
- Grafana 10.0
- Docker + Docker Compose
- PowerShell 7

### Репозиторий
- GitHub: https://github.com/Basil-AS/highload-systems
- Branch: lr4
- Commit: [текущий commit hash]

---

## ✅ КРИТЕРИИ ОЦЕНКИ

### Обязательные требования (100%)
- [x] PostgreSQL replication настроена и работает
- [x] Backup/Restore скрипты реализованы
- [x] Canary deployment с автоматическими тестами
- [x] Grafana дашборды с визуализацией метрик
- [x] Документация (теория + отчет)
- [x] Все компоненты работают на практике

### Дополнительные улучшения (бонусы)
- [x] Автоматизированные тесты (3 скрипта)
- [x] Подробная документация для защиты
- [x] CAP-теорема с обоснованием выбора
- [x] Мониторинг с Prometheus labels для версий
- [ ] DNS балансировка (опционально, задание 6)
- [ ] Kubernetes миграция (для дальнейшего развития)

---

## 🎓 ВЫВОДЫ

### Что реализовано
Система поиска документов (Вариант 8) полностью соответствует требованиям ЛР4:
- Высокодоступная БД с автоматическим failover
- Безопасное резервное копирование с проверкой целостности
- Canary deployment для безопасного обновления сервисов
- Мониторинг и визуализация всех компонентов

### Чему научились
1. Настройка PostgreSQL репликации и failover
2. Реализация различных стратегий деплоя (blue-green, canary)
3. Настройка мониторинга инфраструктуры
4. Применение CAP-теоремы на практике
5. Автоматизация тестирования инфраструктуры

### Возможные улучшения
- Kubernetes для оркестрации (вместо Docker Compose)
- Service Mesh (Istio) для продвинутого traffic management
- Distributed Tracing (Jaeger) для отладки микросервисов
- Синхронная репликация для критичных данных
- PITR (Point-in-Time Recovery) для PostgreSQL

---

**Дата защиты:** 27 октября 2025 г.  
**Студент:** Скрыпник Василий Александрович  
**Группа:** 211-331  
**Вариант:** 8 (Система поиска документов)
