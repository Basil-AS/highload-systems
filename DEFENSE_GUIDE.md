# 🎓 ШПАРГАЛКА ДЛЯ ЗАЩИТЫ ЛР4 - ВЫСОКОНАГРУЖЕННЫЕ СИСТЕМЫ

**Вариант: 8**  
**Студент: Basil-AS**  
**Дата: 27 октября 2025**

---

## 📋 СТРУКТУРА ЗАЩИТЫ (15-20 минут)

1. **Демонстрация кода варианта** (1 мин)
2. **Обзор архитектуры** (2-3 мин)
3. **Теоретическая часть** (3-4 мин)
4. **Практическая демонстрация** (8-10 мин)
5. **Ответы на вопросы** (3-5 мин)

---

## 🎯 ЧАСТЬ 1: КОД ВАРИАНТА (1 минута)

### Что говорить:
> "Добрый день! Представляю лабораторную работу №4 по высоконагруженным системам. Мой вариант рассчитывается по формуле: ((день + месяц² + год) % 25) + 1"

### Команды:

```powershell
# Открыть папку проекта
cd C:\Users\basil\Documents\GitHub\highload-systems

# Показать код варианта
Get-Content get_variant.py

# Выполнить расчёт
python get_variant.py
```

### Ожидаемый результат:
```
Ваш вариант: 8
```

### Что показать:
- Файл `get_variant.py` с формулой расчёта
- Вывод программы: **Вариант 8**

### Пояснение:
> "Для моих данных (10.27.2024) формула даёт вариант 8. Весь проект реализован согласно этому варианту."

---

## 🏗️ ЧАСТЬ 2: ОБЗОР АРХИТЕКТУРЫ (2-3 минуты)

### Что говорить:
> "Проект реализует полноценную высоконагруженную систему поиска документов с микросервисной архитектурой."

### Команды:

```powershell
# Показать структуру проекта
tree /F /A | Select-Object -First 50

# Или более наглядно
Get-ChildItem -Directory | Select-Object Name
```

### Что показать на диаграмме (нарисовать на доске или показать в документации):

```
┌─────────────────────────────────────────────────────────────┐
│                    КЛИЕНТЫ (HTTP)                            │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────────────────┐
│  API GATEWAY (Nginx) - Балансировка + Кэширование           │
│  • Round Robin балансировка                                  │
│  • Canary Deployment (80% v1 / 20% v2)                      │
│  • Proxy cache (100MB, TTL 1h)                              │
└────┬─────────┬─────────┬──────────┬───────────┬─────────────┘
     ↓         ↓         ↓          ↓           ↓
┌─────────┐ ┌───────┐ ┌────────┐ ┌────────┐ ┌──────────┐
│ User v1 │ │User v2│ │Document│ │ Search │ │  Audit   │
│ Service │ │Service│ │Service │ │Service │ │ Service  │
└────┬────┘ └───┬───┘ └───┬────┘ └───┬────┘ └─────┬────┘
     │          │         │           │            │
     └──────────┴─────────┴───────────┴────────────┘
                         ↓
     ┌───────────────────────────────────────────────┐
     │  ДАННЫЕ И ОЧЕРЕДИ                              │
     │  • PostgreSQL (pg_auto_failover - 3 узла)      │
     │  • RabbitMQ (очереди сообщений)                │
     │  • ValKey (кэш Redis-совместимый)              │
     └───────────────────────────────────────────────┘
                         ↓
     ┌───────────────────────────────────────────────┐
     │  МОНИТОРИНГ                                    │
     │  • Prometheus (сбор метрик)                    │
     │  • Grafana (визуализация)                      │
     └───────────────────────────────────────────────┘
```

### Что рассказать про архитектуру:

1. **Трёхзвенная архитектура:**
   - Presentation: Nginx (Gateway)
   - Application: 6 микросервисов на Python/FastAPI
   - Data: PostgreSQL кластер + RabbitMQ + ValKey

2. **Ключевые компоненты:**
   - API Gateway для маршрутизации и кэширования
   - Микросервисы с независимым развёртыванием
   - Репликация БД для отказоустойчивости
   - Асинхронная обработка через очереди
   - Мониторинг всех компонентов

---

## 📚 ЧАСТЬ 3: ТЕОРЕТИЧЕСКАЯ ЧАСТЬ (3-4 минуты)

### Что говорить:
> "Теоретическая часть включает 12 обязательных тем, все описаны в файле lr4_theory.md"

### Команды:

```powershell
# Показать список тем
Get-Content docs\lr4_theory.md | Select-String "^## \d+" | Select-Object -First 12
```

### 12 ОБЯЗАТЕЛЬНЫХ ТЕМ (кратко по каждой):

#### 1. **Трёхзвенная архитектура**
> "Разделение на Presentation (Nginx), Application (микросервисы), Data (PostgreSQL). Преимущества: масштабируемость каждого слоя независимо, разделение ответственности."

#### 2. **Балансировка нагрузки**
> "Реализовано 3 алгоритма: Round Robin в Nginx, Least Connections для базовой балансировки, и DNS Round Robin для географического распределения. У каждого свои плюсы: Round Robin - простота, Least Connections - учёт нагрузки."

#### 3. **Репликация данных**
> "Используется Master-Slave через pg_auto_failover. node2 - Primary (запись), node1 - Secondary (чтение). При отказе Primary автоматический failover на Secondary за 10-30 секунд."

#### 4. **Микросервисная архитектура**
> "6 независимых сервисов: User (v1/v2), Document, Search, Indexer, Audit. Преимущества: независимое развёртывание, отказоустойчивость, разные технологии. Недостатки: сложность координации, распределённые транзакции."

#### 5. **Асинхронная обработка**
> "RabbitMQ для очередей сообщений. Паттерн Producer-Consumer: Audit Service потребляет события из очереди audit_events. Преимущества: сглаживание пиков нагрузки, надёжная доставка."

#### 6. **DNS-балансировка**
> "Симуляция через dnsmasq с Round Robin. Домен search.local резолвится в 3 IP-адреса (127.0.0.1/2/3), имитирующие дата-центры. Каждый запрос идёт на следующий IP по кругу."

#### 7. **Кэширование**
> "Два уровня: Nginx proxy_cache (100MB, TTL 1h) для HTTP-ответов и ValKey (Redis fork) для данных приложения. Стратегия инвалидации: TTL + ручная очистка при изменениях."

#### 8. **Event Sourcing**
> "Audit Service хранит все события как append-only лог. Таблица events с партиционированием по timestamp. Возможность replay событий для восстановления состояния агрегатов."

#### 9. **Мониторинг**
> "Prometheus собирает метрики каждые 15 секунд со всех сервисов. Grafana визуализирует: CPU, память, latency, RPS. Можно настроить алерты на превышение порогов."

#### 10. **Резервное копирование**
> "pg_dump для бэкапов PostgreSQL. Стратегия: полный бэкап Primary + Secondary ежедневно. Скрипты backup.ps1 и restore.ps1. Тест восстановления проверяет целостность данных."

#### 11. **Канареечное развертывание**
> "User Service имеет v1 и v2. Nginx split_clients направляет 80% трафика на v1, 20% на v2. Если v2 работает стабильно - постепенно увеличиваем долю. При ошибках - откатываем."

#### 12. **Партиционирование**
> "Таблица events разделена на 27 месячных партиций (2024-2026). PostgreSQL PARTITION BY RANGE по timestamp. Преимущества: быстрые запросы с фильтром по времени, легкое удаление старых данных."

### Команды для демонстрации теории:

```powershell
# Открыть теоретический файл
code docs\lr4_theory.md

# Или показать оглавление
Get-Content docs\lr4_theory.md | Select-String "^## " | Select-Object -First 20
```

---

## 💻 ЧАСТЬ 4: ПРАКТИЧЕСКАЯ ДЕМОНСТРАЦИЯ (8-10 минут)

### 🔹 4.1. ЗАПУСК СИСТЕМЫ (1 минута)

### Что говорить:
> "Система состоит из двух частей: PostgreSQL кластер и основные сервисы. Запускаю последовательно."

### Команды:

```powershell
# 1. Запуск PostgreSQL кластера с автофейловером
cd pg_auto
docker-compose up -d

# Подождать 10 секунд для инициализации
Start-Sleep -Seconds 10

# 2. Запуск основных сервисов
cd ..
docker-compose up -d

# Подождать 20 секунд для готовности сервисов
Start-Sleep -Seconds 20

# 3. Проверка статуса всех контейнеров
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Ожидаемый результат:
- **15 контейнеров** должны быть в статусе "Up" или "healthy"
- Ключевые: pgauto-monitor, node1, node2, user-service-v1, v2, nginx, rabbitmq, valkey

---

### 🔹 4.2. РЕПЛИКАЦИЯ POSTGRESQL (2 минуты)

### Что говорить:
> "Используется pg_auto_failover для автоматической репликации и failover. Покажу текущее состояние кластера."

### Команды:

```powershell
# Проверка состояния кластера
docker exec pgauto-node1 pg_autoctl show state
```

### Ожидаемый результат:
```
 Name   |  Node |         Host:Port |       TLI: LSN |   Connection |  Current State |  Assigned State
--------+-------+-------------------+----------------+--------------+----------------+-----------------
node_1  |     1 | pgauto-node1:5432 |   2: 0/3BC37A8 |   read-only  |    secondary   |    secondary
node_2  |     2 | pgauto-node2:5432 |   2: 0/3BC37A8 |  read-write  |     primary    |     primary
```

### Что показать:
- **node_2 = Primary** (read-write) - основной узел для записи
- **node_1 = Secondary** (read-only) - реплика для чтения
- **LSN совпадают** - данные синхронизированы

### Команды для проверки репликации:

```powershell
# Создать тестовую таблицу на Primary
docker exec pgauto-node2 psql -U docker -d app_db -c "CREATE TABLE IF NOT EXISTS failover_test (id SERIAL PRIMARY KEY, data TEXT, created_at TIMESTAMP DEFAULT NOW());"

# Вставить данные
docker exec pgauto-node2 psql -U docker -d app_db -c "INSERT INTO failover_test (data) VALUES ('Test replication at $(Get-Date)');"

# Проверить на Secondary (должны появиться данные)
docker exec pgauto-node1 psql -U docker -d app_db -c "SELECT * FROM failover_test ORDER BY id DESC LIMIT 3;"
```

### Что рассказать:
> "Данные, записанные на Primary (node2), автоматически реплицируются на Secondary (node1). При падении Primary, pg_auto_failover автоматически промоутит Secondary в Primary за 10-30 секунд."

---

### 🔹 4.3. КАНАРЕЕЧНОЕ РАЗВЕРТЫВАНИЕ (2 минуты)

### Что говорить:
> "Реализовано канареечное развёртывание для User Service: v1 получает 80% трафика, v2 - 20%. Это позволяет тестировать новую версию на реальных пользователях с минимальным риском."

### Команды:

```powershell
# Показать конфигурацию Nginx
Get-Content services\gateway\nginx.conf | Select-String -Pattern "split_clients|user_backend" -Context 2

# Запустить тест канареечного развертывания
.\scripts\test-canary.ps1
```

### Ожидаемый результат скрипта:
```
🧪 Testing Canary Deployment (User Service v1/v2)

Step 1: Проверка контейнеров...
✅ user-service-v1: Running
✅ user-service-v2: Running

Step 2: Отправка 100 запросов...
█████████████████████████████████████ 100/100

Step 3: Анализ распределения...
v1: 82 requests (82%)
v2: 18 requests (18%)

✅ CANARY DEPLOYMENT РАБОТАЕТ КОРРЕКТНО!
Распределение близко к целевому 80/20
```

### Что показать в коде Nginx:

```nginx
# split_clients для канареечного развертывания
split_clients $remote_addr $backend_variant {
    20%     v2;
    *       v1;
}

# Два upstream
upstream user_backend_v1 {
    server user-service-v1:8000;
}

upstream user_backend_v2 {
    server user-service-v2:8000;
}
```

### Что рассказать:
> "Split_clients в Nginx распределяет трафик на основе IP-адреса клиента. 20% запросов идут на v2, остальные 80% на v1. Если v2 показывает стабильность, можно постепенно увеличивать долю до 100%, затем убрать v1."

---

### 🔹 4.4. DNS БАЛАНСИРОВКА (2 минуты)

### Что говорить:
> "DNS Round Robin симулирует географическое распределение. Домен search.local резолвится в 3 IP-адреса, имитирующие 3 дата-центра."

### Команды:

```powershell
# Запустить DNS инфраструктуру
docker-compose -f docker-compose.dns.yml up -d

# Подождать запуска
Start-Sleep -Seconds 5

# Запустить тест DNS балансировки
.\scripts\test-dns-balancing.ps1
```

### Ожидаемый результат:
```
🧪 Testing DNS Round Robin Balancing

Step 1: Проверка dnsmasq...
✅ dnsmasq работает на порту 5353

Step 2: Проверка nginx инстансов...
✅ nginx-dc1 (порт 8081) - UP
✅ nginx-dc2 (порт 8082) - UP
✅ nginx-dc3 (порт 8083) - UP

Step 3: DNS резолвинг search.local...
Адреса: 127.0.0.1, 127.0.0.2, 127.0.0.3

Step 4: Отправка 30 запросов...
DC1: 10 requests (33%)
DC2: 11 requests (37%)
DC3: 9 requests (30%)

✅ DNS ROUND ROBIN РАБОТАЕТ КОРРЕКТНО!
```

### Что показать в конфигурации:

```powershell
# Показать dnsmasq.conf
Get-Content dns\dnsmasq.conf | Select-String -Pattern "address=" -Context 1
```

### Конфиг dnsmasq:
```
# Round Robin DNS для search.local
address=/search.local/127.0.0.1
address=/search.local/127.0.0.2
address=/search.local/127.0.0.3
```

### Что рассказать:
> "dnsmasq отвечает на DNS-запросы для search.local, возвращая 3 IP-адреса. Клиент выбирает один случайно или по кругу. Это имитирует GeoDNS, где пользователи из разных регионов получают ближайший IP."

---

### 🔹 4.5. EVENT SOURCING С ПАРТИЦИОНИРОВАНИЕМ (2 минуты)

### Что говорить:
> "Audit Service использует Event Sourcing: все изменения хранятся как события. Таблица events партиционирована по времени - 27 месячных партиций."

### Команды:

```powershell
# Запустить тест Event Sourcing
.\scripts\test-event-sourcing.ps1
```

### Ожидаемый результат:
```
🧪 Testing Event Sourcing with Partitioning

Step 1: Проверка PostgreSQL...
✅ PostgreSQL контейнеры найдены

Step 2: Инициализация партиционированной БД...
✅ Database initialized with partitions

Step 3: Проверка партиций...
✅ Найдено 27 партиций:
events_2024_10, events_2024_11, ..., events_2026_12

Step 4: Вставка тестовых событий...
✅ Вставлено 5 тестовых событий

Step 5: Проверка распределения данных...
Partition: events_2024_10, Rows: 2
Partition: events_2025_01, Rows: 1
Partition: events_2025_06, Rows: 1
Partition: events_2025_12, Rows: 1

Step 6: Тест partition pruning...
✅ Partition pruning работает! Запрос сканирует только events_2025_01

Step 7: Event Replay для user-001...
Event history:
- 2024-10-15: created (name: Alice)
- 2024-11-20: updated (email: alice.updated@example.com)
Reconstructed state: {"name": "Alice", "email": "alice.updated@example.com"}

✅ EVENT SOURCING С ПАРТИЦИОНИРОВАНИЕМ РАБОТАЕТ!
```

### Что показать в SQL:

```powershell
# Показать создание партиций
Get-Content services\audit-service\init-db.sql | Select-String -Pattern "CREATE TABLE events_" -Context 1 | Select-Object -First 10
```

### Что рассказать:
> "Партиционирование по времени даёт 2 преимущества: 1) Запросы с фильтром по дате сканируют только нужные партиции (partition pruning), 2) Старые партиции можно легко удалить через DROP TABLE без нагрузки на основную таблицу."

### Демонстрация Event Replay:

```powershell
# Показать события для агрегата
docker exec pgauto-node2 psql -U docker -d app_db -c "SELECT event_type, event_data, timestamp FROM events WHERE aggregate_id='user-001' ORDER BY timestamp;"
```

### Что рассказать:
> "Event Sourcing позволяет 'прокрутить' все события для агрегата и восстановить его текущее состояние. Это полезно для аудита, отладки и восстановления после ошибок."

---

### 🔹 4.6. МОНИТОРИНГ (1 минута)

### Что говорить:
> "Prometheus собирает метрики, Grafana их визуализирует. Можно отслеживать нагрузку, ошибки, latency в реальном времени."

### Команды:

```powershell
# Открыть Prometheus в браузере
Start-Process http://localhost:9090

# Открыть Grafana
Start-Process http://localhost:3000
```

### Что показать в Prometheus:
1. **Status → Targets** - список всех сервисов (должны быть UP)
2. **Graph** - выполнить запросы:
   - `up` - доступность сервисов
   - `process_cpu_seconds_total` - использование CPU
   - `http_requests_total` - количество запросов

### Что показать в Grafana:
1. **Логин**: admin / admin
2. **Dashboard**: System Overview
3. **Панели**:
   - CPU Usage
   - Memory Usage
   - HTTP Request Rate
   - Request Latency

### Что рассказать:
> "Prometheus scrape'ит метрики каждые 15 секунд с endpoint `/metrics` каждого сервиса. Grafana строит графики на основе этих данных. Можно настроить алерты в Alertmanager для уведомлений в Telegram/Email."

---

### 🔹 4.7. РЕЗЕРВНОЕ КОПИРОВАНИЕ (1 минута)

### Что говорить:
> "Реализованы скрипты для автоматического бэкапа и восстановления PostgreSQL кластера."

### Команды:

```powershell
# Запустить полный тест backup/restore
.\scripts\test-backup-restore.ps1
```

### Ожидаемый результат:
```
🧪 Testing Backup and Restore

Step 1: Проверка PostgreSQL кластера...
✅ pgauto-node1 доступен
✅ pgauto-node2 доступен

Step 2: Создание тестовых данных...
✅ Вставлено 5 тестовых записей

Step 3: Создание бэкапа...
✅ Backup успешно создан: backups/backup_node1_20251027_143022.sql

Step 4: Удаление данных...
✅ Тестовые данные удалены

Step 5: Восстановление из бэкапа...
✅ Restore успешно выполнен

Step 6: Проверка целостности данных...
✅ Все 5 записей восстановлены корректно

✅ BACKUP И RESTORE РАБОТАЮТ КОРРЕКТНО!
```

### Что показать в коде:

```powershell
# Показать скрипт backup
Get-Content scripts\backup.ps1 | Select-String -Pattern "pg_dump|docker exec" -Context 2
```

### Что рассказать:
> "Скрипт backup.ps1 создаёт дампы обоих узлов кластера через pg_dump. Restore.ps1 восстанавливает данные через psql. В продакшене это запускается по cron ежедневно + копирование в S3/удалённое хранилище."

---

## ❓ ЧАСТЬ 5: ОТВЕТЫ НА ТИПИЧНЫЕ ВОПРОСЫ

### Вопрос 1: "Почему выбрали именно pg_auto_failover?"
**Ответ:**
> "pg_auto_failover обеспечивает автоматический failover без manual intervention. При падении Primary автоматически промоутит Secondary за 10-30 секунд. Альтернативы (Patroni, repmgr) требуют Consul/etcd для координации, что усложняет архитектуру."

### Вопрос 2: "Как обеспечивается консистентность данных при репликации?"
**Ответ:**
> "Используется синхронная репликация. Primary ждёт подтверждения от Secondary перед commit'ом транзакции. Это гарантирует, что данные не потеряются при failover, но добавляет latency ~5-10ms."

### Вопрос 3: "Что если упадёт один из микросервисов?"
**Ответ:**
> "Остальные продолжат работать. Nginx вернёт 503 для упавшего сервиса. В docker-compose настроен `restart: unless-stopped`, поэтому сервис автоматически перезапустится. Для продакшена добавил бы health checks и circuit breaker в Gateway."

### Вопрос 4: "Как масштабировать систему при росте нагрузки?"
**Ответ:**
> "Горизонтально: добавлять реплики микросервисов через docker-compose scale. Вертикально: увеличивать ресурсы контейнеров. Для БД: добавлять read-реплики, шардинг по user_id. Для RabbitMQ: кластеризация с federation."

### Вопрос 5: "Почему split_clients, а не weighted round-robin?"
**Ответ:**
> "split_clients детерминирован - один IP всегда идёт на одну версию. Это важно для A/B тестирования и сессий. weighted round-robin случаен, пользователь может попадать на разные версии в разных запросах."

### Вопрос 6: "Как измерять производительность системы?"
**Ответ:**
> "Основные метрики: 1) RPS (requests per second) из Prometheus, 2) Latency p50/p95/p99 из гистограмм, 3) Error rate (5xx ответы), 4) Saturation (CPU/Memory) контейнеров. Для нагрузочного тестирования: Apache Bench, k6, Locust."

### Вопрос 7: "Что делать с старыми партициями событий?"
**Ответ:**
> "В init-db.sql есть функция `drop_old_partitions()`, которая удаляет партиции старше 2 лет. Можно запускать по cron ежемесячно. Альтернатива: архивировать партиции в S3 перед удалением для долгосрочного хранения."

### Вопрос 8: "Как обеспечивается безопасность?"
**Ответ:**
> "В текущей версии basic security: credentials в environment variables, trust-аутентификация для PostgreSQL. Для продакшена добавил бы: 1) JWT-токены в API Gateway, 2) SSL/TLS для БД и RabbitMQ, 3) Network policies для изоляции сервисов, 4) Vault для секретов."

### Вопрос 9: "Как тестировать микросервисы?"
**Ответ:**
> "3 уровня: 1) Unit-тесты для бизнес-логики (pytest), 2) Integration тесты для API endpoints (TestClient FastAPI), 3) E2E тесты для всей системы (мои PowerShell скрипты). Добавил бы contract testing (Pact) для проверки совместимости версий."

### Вопрос 10: "Почему ValKey, а не Redis?"
**Ответ:**
> "ValKey - это open-source fork Redis после смены лицензии Redis Ltd. Полностью совместим с Redis, но без рисков лицензионных ограничений. Поддерживается Linux Foundation."

---

## 📊 ЧАСТЬ 6: ДЕМОНСТРАЦИЯ ДОКУМЕНТАЦИИ

### Что говорить:
> "Вся документация структурирована и покрывает все требования задания."

### Команды:

```powershell
# Показать список документов
Get-ChildItem docs\ -File | Select-Object Name, Length

# Показать чеклист
code docs\FINAL_CHECKLIST.md
```

### Что показать:

1. **FINAL_CHECKLIST.md** (500 строк)
   - Полный список всех требований
   - Статус выполнения: 12/12 теории, 12/12 практики

2. **lr4_theory.md** (2000 строк)
   - Все 12 теоретических тем
   - Диаграммы, примеры кода

3. **dns_balancing.md** (250 строк)
   - Архитектура DNS Round Robin
   - Конфигурация dnsmasq
   - Примеры использования

4. **event_sourcing_partitioning.md** (500 строк)
   - SQL-схема с партициями
   - Event Replay алгоритм
   - Best practices

5. **README.md** (800 строк)
   - Быстрый старт
   - Архитектура системы
   - Инструкции по запуску

### Команды для подсчёта:

```powershell
# Общий объём документации
Get-ChildItem docs\ -File -Recurse | Measure-Object -Property Length -Sum | Select-Object @{Name="Total MB";Expression={[math]::Round($_.Sum/1MB, 2)}}, Count

# Подсчёт строк во всех MD файлах
Get-ChildItem -Recurse -Filter *.md | ForEach-Object {
    $lines = (Get-Content $_.FullName).Count
    [PSCustomObject]@{File=$_.Name; Lines=$lines}
} | Sort-Object Lines -Descending | Format-Table -AutoSize
```

---

## 🎯 ФИНАЛЬНЫЙ ЧЕКЛИСТ ДЛЯ ЗАЩИТЫ

### ✅ Перед началом защиты:

- [ ] Все контейнеры запущены (`docker ps` показывает 15 контейнеров)
- [ ] PostgreSQL кластер в состоянии healthy
- [ ] Prometheus доступен на localhost:9090
- [ ] Grafana доступен на localhost:3000
- [ ] Все скрипты протестированы и работают
- [ ] Документация открыта в VS Code
- [ ] Презентация/диаграммы готовы

### ✅ Во время защиты:

- [ ] Показать код варианта (1 мин)
- [ ] Рассказать архитектуру с диаграммой (2 мин)
- [ ] Пробежаться по 12 теоретическим темам (3 мин)
- [ ] Демонстрация репликации (2 мин)
- [ ] Демонстрация канареечного развертывания (2 мин)
- [ ] Демонстрация DNS балансировки (2 мин)
- [ ] Демонстрация Event Sourcing (2 мин)
- [ ] Показать мониторинг (1 мин)
- [ ] Показать backup/restore (1 мин)

### ✅ При ответах на вопросы:

- [ ] Говорить уверенно, ссылаться на реальную реализацию
- [ ] Показывать код при необходимости
- [ ] Признавать упрощения (например, "это MVP, в продакшене добавил бы...")
- [ ] Упоминать альтернативные решения

---

## 🚀 БЫСТРЫЙ СТАРТ В ДЕНЬ ЗАЩИТЫ

### За 10 минут до защиты:

```powershell
# 1. Открыть проект
cd C:\Users\basil\Documents\GitHub\highload-systems

# 2. Запустить PostgreSQL кластер
cd pg_auto
docker-compose up -d
cd ..

# 3. Подождать инициализации
Start-Sleep -Seconds 10

# 4. Запустить основные сервисы
docker-compose up -d

# 5. Подождать готовности
Start-Sleep -Seconds 20

# 6. Проверить статус
docker ps --format "table {{.Names}}\t{{.Status}}"

# 7. Открыть документацию
code docs\FINAL_CHECKLIST.md

# 8. Открыть Prometheus и Grafana в браузере
Start-Process http://localhost:9090
Start-Process http://localhost:3000

# 9. Проверить вариант
python get_variant.py

# 10. Всё готово! ✅
```

---

## 📌 ШПАРГАЛКА ПО КОМАНДАМ (копировать-вставлять)

```powershell
# КОД ВАРИАНТА
python get_variant.py

# РЕПЛИКАЦИЯ
docker exec pgauto-node1 pg_autoctl show state

# КАНАРЕЕЧНОЕ РАЗВЕРТЫВАНИЕ
.\scripts\test-canary.ps1

# DNS БАЛАНСИРОВКА
docker-compose -f docker-compose.dns.yml up -d
.\scripts\test-dns-balancing.ps1

# EVENT SOURCING
.\scripts\test-event-sourcing.ps1

# BACKUP/RESTORE
.\scripts\test-backup-restore.ps1

# МОНИТОРИНГ
Start-Process http://localhost:9090
Start-Process http://localhost:3000

# СТАТУС КОНТЕЙНЕРОВ
docker ps --format "table {{.Names}}\t{{.Status}}"

# СПИСОК ДОКУМЕНТАЦИИ
Get-ChildItem docs\ -File | Select-Object Name, @{Name="Lines";Expression={(Get-Content $_.FullName).Count}}
```

---

## 🎓 СОВЕТЫ ДЛЯ УСПЕШНОЙ ЗАЩИТЫ

1. **Будьте уверены**: Вы реализовали ВСЕ требования, знаете свой код
2. **Говорите чётко**: Используйте технические термины правильно
3. **Показывайте, не рассказывайте**: Больше демонстрации, меньше слов
4. **Признавайте упрощения**: "Для MVP достаточно, в продакшене добавил бы..."
5. **Знайте альтернативы**: Patroni vs pg_auto_failover, Redis vs ValKey
6. **Держите ритм**: 15-20 минут - не тараторьте, но и не затягивайте
7. **Отвечайте по сути**: Если не знаете - скажите "Не сталкивался, но изучу"
8. **Будьте готовы к сбоям**: Если контейнер упал - перезапустите, это нормально

---

## 🏆 ФИНАЛЬНЫЕ СЛОВА ДЛЯ ПРЕПОДАВАТЕЛЯ

> "В заключение: проект реализует полноценную высоконагруженную систему с микросервисной архитектурой, автоматической репликацией, канареечным развертыванием, DNS-балансировкой, Event Sourcing с партиционированием и полным мониторингом. Все 12 теоретических тем описаны, все 12 практических требований выполнены. Система задокументирована (4500+ строк), покрыта автоматическими тестами и готова к демонстрации. Спасибо за внимание, готов ответить на вопросы!"

---

**Удачи на защите! 🚀**

*P.S. Если что-то пойдёт не так - не паникуйте, перезапустите контейнеры и продолжайте. Вы отлично подготовились!*
