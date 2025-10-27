# Event Sourcing с Партиционированием

## 📋 Описание

Реализация паттерна Event Sourcing с **партиционированием по времени** для высоконагруженных систем. База данных событий разделена на месячные партиции для оптимизации производительности и управления данными.

## 🏗️ Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                     Audit Service (FastAPI)                  │
│  - Запись событий через POST /events                         │
│  - Воспроизведение событий GET /replay/{type}/{id}          │
│  - Получение истории GET /events/{type}/{id}                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────────┐
        │   RabbitMQ (audit_events)  │
        │   Асинхронная обработка     │
        └────────────┬───────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              PostgreSQL Events Table (PARTITIONED)          │
├─────────────────────────────────────────────────────────────┤
│  Главная таблица: events                                    │
│  Ключ партиционирования: timestamp (RANGE)                  │
├─────────────────────────────────────────────────────────────┤
│  Партиции (по месяцам):                                     │
│  ├─ events_2024_10  [2024-10-01 .. 2024-11-01)            │
│  ├─ events_2024_11  [2024-11-01 .. 2024-12-01)            │
│  ├─ events_2024_12  [2024-12-01 .. 2025-01-01)            │
│  ├─ events_2025_01  [2025-01-01 .. 2025-02-01)            │
│  ├─ ...                                                     │
│  ├─ events_2025_12  [2025-12-01 .. 2026-01-01)            │
│  └─ events_2026_12  [2026-12-01 .. 2027-01-01)            │
└─────────────────────────────────────────────────────────────┘
```

## 📊 Структура Событий

### Таблица `events`

| Колонка         | Тип          | Описание                              |
|-----------------|--------------|---------------------------------------|
| id              | UUID         | Уникальный ID события                 |
| aggregate_type  | VARCHAR(50)  | Тип агрегата (user/document/search)   |
| aggregate_id    | VARCHAR(255) | ID агрегата                           |
| event_type      | VARCHAR(50)  | Тип события (created/updated/deleted) |
| event_data      | JSONB        | Данные события (гибкая структура)     |
| user_id         | VARCHAR(255) | ID пользователя (опционально)         |
| timestamp       | TIMESTAMPTZ  | **Ключ партиционирования**            |

### Индексы

```sql
-- GIN для поиска по JSONB
CREATE INDEX idx_events_event_data ON events USING GIN (event_data);

-- B-tree для частых запросов
CREATE INDEX idx_events_aggregate ON events (aggregate_type, aggregate_id, timestamp);
CREATE INDEX idx_events_user ON events (user_id, timestamp) WHERE user_id IS NOT NULL;
CREATE INDEX idx_events_type ON events (event_type, timestamp);
```

## 🚀 Партиционирование

### Стратегия: BY RANGE (timestamp)

- **Период партиции**: 1 месяц
- **Покрытие**: 2024-2026 (3 года, 27 партиций)
- **Автоматическое создание**: функция `create_next_partition()`
- **Автоочистка**: функция `drop_old_partitions()` (удаляет данные старше 2 лет)

### Преимущества Партиционирования

1. **Производительность**:
   - Запросы с фильтром по времени работают только с нужными партициями
   - Параллельное сканирование партиций
   - Меньше данных для индексов на каждую партицию

2. **Управление Данными**:
   - Легкое удаление старых данных (DROP TABLE events_2023_01)
   - Архивация по партициям
   - Отдельные backup'ы для каждого периода

3. **Масштабируемость**:
   - Добавление новых партиций без блокировок
   - Распределение I/O нагрузки
   - Упрощение sharding'а в будущем

## 📝 Использование

### 1. Инициализация БД

```powershell
# Подключиться к PostgreSQL контейнеру
docker exec -i highload-systems-pgauto-node1-1 psql -U postgres -d audit_db < services/audit-service/init-db.sql

# Или через docker-compose
docker-compose exec pgauto-node1 psql -U postgres -d audit_db -f /docker-entrypoint-initdb.d/init-db.sql
```

### 2. Запись События

**Python (через Audit Service API):**

```python
import httpx

event = {
    "aggregate_type": "user",
    "aggregate_id": "user-12345",
    "event_type": "created",
    "event_data": {
        "name": "John Doe",
        "email": "john@example.com",
        "role": "admin"
    },
    "user_id": "admin-001"
}

response = httpx.post("http://localhost:8006/events", json=event)
print(response.json())  # {"status": "recorded", "event_id": "user-12345"}
```

**Через RabbitMQ:**

```python
import pika
import json

connection = pika.BlockingConnection(pika.URLParameters('amqp://admin:admin@localhost:5672/'))
channel = connection.channel()

event = {
    "aggregate_type": "document",
    "aggregate_id": "doc-98765",
    "event_type": "updated",
    "event_data": {"title": "New Title", "status": "published"}
}

channel.basic_publish(
    exchange='',
    routing_key='audit_events',
    body=json.dumps(event),
    properties=pika.BasicProperties(delivery_mode=2)  # persistent
)

connection.close()
```

### 3. Воспроизведение (Event Replay)

Восстановление текущего состояния агрегата из всех его событий:

```python
response = httpx.get("http://localhost:8006/replay/user/user-12345")
print(response.json())

# Output:
# {
#   "aggregate_id": "user-12345",
#   "aggregate_type": "user",
#   "current_state": {
#     "name": "John Doe",
#     "email": "john.updated@example.com",
#     "role": "admin",
#     "verified": true
#   },
#   "events_count": 5
# }
```

### 4. Получение Истории Событий

```python
response = httpx.get(
    "http://localhost:8006/events/user/user-12345",
    params={"limit": 10, "offset": 0}
)
events = response.json()

for event in events:
    print(f"{event['timestamp']}: {event['event_type']} - {event['event_data']}")
```

## 🔧 Управление Партициями

### Создание Новой Партиции

```sql
-- Автоматически через функцию
SELECT create_next_partition();

-- Вручную
CREATE TABLE events_2027_01 PARTITION OF events
    FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');
```

### Просмотр Партиций

```sql
-- Информация о размерах партиций
SELECT * FROM partition_info;

-- Список всех партиций
SELECT tablename, pg_size_pretty(pg_total_relation_size(tablename::regclass))
FROM pg_tables
WHERE tablename LIKE 'events_%'
ORDER BY tablename;

-- Распределение данных по партициям
SELECT 
    tableoid::regclass AS partition_name,
    count(*) as events_count,
    min(timestamp) as first_event,
    max(timestamp) as last_event
FROM events
GROUP BY tableoid
ORDER BY partition_name;
```

### Удаление Старых Партиций

```sql
-- Автоматически (старше 2 лет)
SELECT drop_old_partitions();

-- Вручную
DROP TABLE events_2022_01;
```

### Архивация Партиции

```powershell
# Экспорт партиции в файл
docker exec highload-systems-pgauto-node1-1 pg_dump -U postgres -d audit_db -t events_2024_10 > archive/events_2024_10.sql

# Восстановление из архива
docker exec -i highload-systems-pgauto-node1-1 psql -U postgres -d audit_db < archive/events_2024_10.sql
```

## 📈 Мониторинг

### Prometheus Метрики

Audit Service экспортирует метрики на `/metrics`:

```
# Записанные события (по типам)
audit_events_recorded_total{aggregate_type="user",event_type="created"} 1523
audit_events_recorded_total{aggregate_type="document",event_type="updated"} 892

# Запросы на воспроизведение
audit_replay_requests_total{aggregate_type="user"} 234

# Длительность воспроизведения (гистограмма)
audit_replay_duration_seconds_bucket{le="0.1"} 180
audit_replay_duration_seconds_bucket{le="0.5"} 230
audit_replay_duration_seconds_sum 45.2
audit_replay_duration_seconds_count 234
```

### SQL Запросы для Мониторинга

```sql
-- События за последний час (использует текущую партицию)
SELECT count(*) 
FROM events 
WHERE timestamp > NOW() - INTERVAL '1 hour';

-- Топ агрегатов по количеству событий
SELECT aggregate_type, count(*) as events_count
FROM events
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY aggregate_type
ORDER BY events_count DESC;

-- Средний размер event_data
SELECT 
    aggregate_type,
    pg_size_pretty(avg(pg_column_size(event_data))::bigint) as avg_data_size
FROM events
GROUP BY aggregate_type;

-- Производительность партиций
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS indexes_size
FROM pg_tables
WHERE tablename LIKE 'events_%'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## 🧪 Тестирование

### Тест Партиционирования

```sql
-- Вставить события в разные партиции
INSERT INTO events (aggregate_type, aggregate_id, event_type, event_data, timestamp)
VALUES 
    ('test', 'test-1', 'created', '{"data": "2024-10"}', '2024-10-15'::timestamptz),
    ('test', 'test-2', 'created', '{"data": "2025-06"}', '2025-06-15'::timestamptz),
    ('test', 'test-3', 'created', '{"data": "2026-12"}', '2026-12-25'::timestamptz);

-- Проверить распределение по партициям
SELECT 
    tableoid::regclass AS partition_name,
    aggregate_id,
    timestamp
FROM events
WHERE aggregate_type = 'test'
ORDER BY timestamp;

-- Очистить тестовые данные
DELETE FROM events WHERE aggregate_type = 'test';
```

### Тест Производительности

```powershell
# Скрипт для нагрузочного тестирования
# test-event-sourcing.ps1

$url = "http://localhost:8006/events"
$totalEvents = 1000

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

for ($i = 1; $i -le $totalEvents; $i++) {
    $event = @{
        aggregate_type = "benchmark"
        aggregate_id = "bench-$i"
        event_type = "created"
        event_data = @{
            index = $i
            timestamp = (Get-Date).ToString("o")
        }
    } | ConvertTo-Json

    Invoke-RestMethod -Uri $url -Method Post -Body $event -ContentType "application/json" | Out-Null
    
    if ($i % 100 -eq 0) {
        Write-Host "Processed $i events..."
    }
}

$stopwatch.Stop()
$rps = [math]::Round($totalEvents / $stopwatch.Elapsed.TotalSeconds, 2)

Write-Host "`n✅ Записано $totalEvents событий за $($stopwatch.Elapsed.TotalSeconds) секунд"
Write-Host "📊 Производительность: $rps событий/сек"
```

## 🔍 Анализ Данных

### JSONB Запросы

```sql
-- Поиск по полю в event_data
SELECT * FROM events
WHERE event_data @> '{"status": "published"}';

-- Извлечение поля из JSONB
SELECT 
    aggregate_id,
    event_data->>'email' as email,
    timestamp
FROM events
WHERE aggregate_type = 'user'
  AND event_data ? 'email';

-- Фильтр по вложенному полю
SELECT * FROM events
WHERE event_data->'metadata'->>'source' = 'api';
```

### Агрегация по Временным Периодам

```sql
-- События по дням за последнюю неделю
SELECT 
    DATE(timestamp) as event_date,
    count(*) as events_count
FROM events
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY DATE(timestamp)
ORDER BY event_date;

-- События по часам за последний день
SELECT 
    DATE_TRUNC('hour', timestamp) as event_hour,
    aggregate_type,
    count(*) as events_count
FROM events
WHERE timestamp > NOW() - INTERVAL '1 day'
GROUP BY event_hour, aggregate_type
ORDER BY event_hour DESC;
```

## 🛠️ Обслуживание

### Регулярные Задачи (Cron Jobs)

```bash
# Создание новых партиций (ежемесячно)
0 0 1 * * docker exec highload-systems-pgauto-node1-1 psql -U postgres -d audit_db -c "SELECT create_next_partition();"

# Удаление старых партиций (ежеквартально)
0 2 1 */3 * docker exec highload-systems-pgauto-node1-1 psql -U postgres -d audit_db -c "SELECT drop_old_partitions();"

# Backup активных партиций (еженедельно)
0 3 * * 0 docker exec highload-systems-pgauto-node1-1 pg_dump -U postgres -d audit_db -t "events_$(date +\%Y_\%m)*" > /backups/events_$(date +\%Y\%m\%d).sql
```

### VACUUM и ANALYZE

```sql
-- Анализ статистики (после массовой вставки)
ANALYZE events;

-- Очистка удаленных строк
VACUUM ANALYZE events;

-- Полная очистка (освобождение места)
VACUUM FULL events_2024_10;
```

## 📚 Best Practices

1. **Всегда включайте timestamp в WHERE**:
   ```sql
   -- ✅ Хорошо (использует partition pruning)
   SELECT * FROM events 
   WHERE timestamp > '2025-01-01' AND aggregate_id = 'user-123';
   
   -- ❌ Плохо (сканирует все партиции)
   SELECT * FROM events WHERE aggregate_id = 'user-123';
   ```

2. **Используйте составные индексы**:
   ```sql
   -- Для частых запросов по типу + ID + времени
   CREATE INDEX ON events (aggregate_type, aggregate_id, timestamp);
   ```

3. **Batch вставки для производительности**:
   ```python
   # Вместо 1000 INSERT'ов
   events = [...]
   conn.executemany("""
       INSERT INTO events (aggregate_type, aggregate_id, event_type, event_data)
       VALUES (?, ?, ?, ?)
   """, events)
   ```

4. **Мониторинг размеров партиций**:
   - Проверяйте `partition_info` еженедельно
   - Архивируйте большие партиции
   - Удаляйте неиспользуемые партиции

5. **Backup стратегия**:
   - Полный backup кластера ежедневно
   - Инкрементальный backup партиций
   - Тестируйте восстановление

## 🔗 Интеграция

### Docker Compose

```yaml
services:
  audit-service:
    build: ./services/audit-service
    ports:
      - "8006:8000"
    environment:
      DATABASE_URL: postgresql://postgres:postgres@pgauto-node1:5432/audit_db
      RABBITMQ_URL: amqp://admin:admin@rabbitmq:5672/
    volumes:
      - ./services/audit-service/init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
    depends_on:
      - pgauto-node1
      - rabbitmq
```

### Prometheus Scraping

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'audit-service'
    static_configs:
      - targets: ['audit-service:8000']
    metrics_path: '/metrics'
    scrape_interval: 15s
```

## 📖 Дополнительные Ресурсы

- [PostgreSQL Table Partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html)
- [Event Sourcing Pattern](https://martinfowler.com/eaaDev/EventSourcing.html)
- [JSONB Performance](https://www.postgresql.org/docs/current/datatype-json.html)
- [pg_partman Extension](https://github.com/pgpartman/pg_partman)

---

**Разработано для**: ЛР4 "Высоконагруженные системы"  
**Вариант**: 8  
**Требование**: Event Sourcing и партиционирование по времени
