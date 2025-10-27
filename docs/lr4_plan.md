# ЛР4 — План выполнения (Вариант 8: Поисковая система)

**Дата создания плана:** 26 октября 2025  
**Ветка:** lr4  
**Вариант:** 8 — Поисковая система  
**Основные вызовы:** Индексация больших коллекций документов, сложные запросы, кэширование результатов

---

## Структура проекта

```
highload-systems/
├── get_variant.py                    # Скрипт определения варианта (выводит 8)
├── docs/
│   ├── task_LR4.txt                 # Задание
│   ├── lr4_plan.md                  # Этот план
│   ├── lr4_theory.md                # Теоретическая часть (11 тем)
│   ├── lr4_report.md                # Итоговый отчет
│   └── architecture/
│       ├── high_level.mmd           # High-level диаграмма
│       ├── microservices.mmd        # Микросервисная архитектура
│       ├── deployment.mmd           # Схема развертывания
│       └── cap_analysis.md          # Анализ CAP-теоремы
├── docker-compose.yml               # Основной compose-файл
├── docker-compose.canary.yml        # Для канареечного развертывания
├── services/
│   ├── gateway/                     # Nginx (балансировка + кэш)
│   │   ├── nginx.conf
│   │   ├── Dockerfile
│   │   └── static/                  # Frontend статика
│   ├── user-service/                # Микросервис пользователей
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   ├── main.py                  # FastAPI app
│   │   └── models/
│   ├── document-service/            # Микросервис документов
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── main.py
│   ├── search-service/              # Микросервис поиска
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── main.py
│   ├── indexer-worker/              # Воркер индексации
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── worker.py
│   └── audit-service/               # Event Sourcing сервис
│       ├── Dockerfile
│       ├── requirements.txt
│       └── main.py
├── database/
│   ├── init-scripts/
│   │   ├── 01-init-databases.sql   # Создание БД
│   │   ├── 02-create-schemas.sql   # Схемы для всех сервисов
│   │   └── 03-partitions.sql       # Партиции для audit
│   ├── backup/
│   │   ├── backup.sh                # Скрипт бэкапа
│   │   └── restore.sh               # Скрипт восстановления
│   └── replication/
│       └── setup-replication.sh
├── monitoring/
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── alerts.yml
│   ├── grafana/
│   │   ├── dashboards/
│   │   └── datasources/
│   └── exporters/
├── scripts/
│   ├── deploy.sh                    # Развертывание системы
│   ├── test-failover.sh             # Тест отказоустойчивости
│   ├── simulate-load.py             # Генерация нагрузки
│   ├── dns-setup.sh                 # Настройка DNS-симуляции
│   └── rollback-canary.sh           # Откат канареечного деплоя
└── README.md                        # Инструкции по запуску

```

---

## Этапы выполнения

### ЭТАП 0: Подготовка и изучение (✅ СДЕЛАНО)
- [x] Изучить задание ЛР4
- [x] Определить вариант (8 - Поисковая система)
- [x] Проанализировать наработки (pg_auto docker-compose)
- [x] Создать структурированный план

### ЭТАП 1: Теоретическая часть (11 обязательных тем)

**Файл:** `docs/lr4_theory.md`

- [ ] 1.1. Монолитные vs сервис-ориентированные архитектуры
- [ ] 1.2. Горизонтальное vs вертикальное масштабирование
- [ ] 1.3. Трехзвенная архитектура (Presentation, Application, Data)
- [ ] 1.4. Обработка запросов фронтендом и бэкендом
- [ ] 1.5. Кэширование и отдача статики
- [ ] 1.6. Вычисления на стороне клиента
- [ ] 1.7. Масштабирование фронтенда и бэкенда
- [ ] 1.8. DNS-балансировка (Round Robin DNS)
- [ ] 1.9. Отказоустойчивость (резервирование, failover)
- [ ] 1.10. Масштабирование баз данных (шардинг, репликация, партиционирование)
- [ ] 1.11. CAP-теорема и компромиссы

**Формат:** Каждый раздел 1-2 страницы с диаграммами (Mermaid/ASCII), примерами, преимуществами/недостатками.

### ЭТАП 2: Проектирование архитектуры поисковой системы

**Файлы:** `docs/architecture/*.mmd`, `docs/architecture/cap_analysis.md`

#### 2.1. Определение требований и вызовов
- [ ] Описать специфику поисковой системы:
  - Индексация 100К+ документов
  - Поиск по full-text с латенси < 100ms
  - Пиковая нагрузка: 1000 RPS
  - Асинхронная индексация новых документов
- [ ] Определить метрики: QPS, P95 latency, индекс актуальности
- [ ] Выявить узкие места: БД, индексация, кэш

#### 2.2. Микросервисная архитектура
- [ ] **User Service**: аутентификация, профили, квоты запросов
- [ ] **Document Service**: CRUD документов, метаданные
- [ ] **Search Service**: full-text поиск, ранжирование результатов
- [ ] **Indexer Worker**: асинхронная индексация через очередь
- [ ] **Audit Service**: Event Sourcing для всех изменений
- [ ] API Gateway (Nginx): маршрутизация, rate limiting

#### 2.3. Взаимодействие сервисов
- [ ] REST API между сервисами (синхронное)
- [ ] Message Queue для асинхронных задач (RabbitMQ/ValKey)
- [ ] Event Bus для аудита (Kafka/RabbitMQ)

#### 2.4. Хранение данных
- [ ] **PostgreSQL Primary/Replica**:
  - `users_db`: пользователи, сессии
  - `documents_db`: документы (JSONB для контента)
  - `search_db`: инвертированный индекс (terms, postings)
  - `audit_db`: события с партиционированием по дате
- [ ] **ValKey (Redis)**: кэш результатов поиска, rate limiting
- [ ] Репликация: Primary (write) → Standby (read для поиска)

#### 2.5. Индексация (специфика поисковой системы)
```
Документ загружен → Queue → Indexer Worker → 
→ Токенизация → Построение inverted index → 
→ Запись в search_db → Cache invalidation
```
- [ ] Таблицы: `documents`, `terms`, `postings` (term_id, doc_id, position, tf-idf)
- [ ] Партиционирование `postings` по первой букве term или hash
- [ ] GIN индексы в PostgreSQL для JSONB контента

#### 2.6. Кэширование
- [ ] **L1 (Nginx)**: статика, API responses (proxy_cache, 1 min TTL)
- [ ] **L2 (ValKey)**: результаты поиска (5 min TTL), топ-запросы
- [ ] **L3 (PostgreSQL)**: подготовленные выборки (materialized views)
- [ ] Стратегия инвалидации: при индексации новых документов → flush по тегам

#### 2.7. CAP-теорема для поисковой системы
- [ ] **Выбор компромисса**: **AP** (Availability + Partition Tolerance)
  - Поиск должен работать даже при частичной недоступности данных
  - Eventual consistency: новые документы могут индексироваться с задержкой (приемлемо)
  - Для User Service: **CP** (строгая консистентность авторизации)
- [ ] Анализ сценариев:
  - Падение Primary БД → переключение на Replica (поиск работает read-only)
  - Задержка репликации → пользователь может не увидеть свой документ 1-2 сек (acceptable)
  - Network partition → API Gateway продолжает работать с кэшем

#### 2.8. Диаграммы
- [ ] `high_level.mmd`: Client → DNS → Nginx → Services → DB/Queue/Cache
- [ ] `microservices.mmd`: Детальная схема взаимодействия сервисов
- [ ] `deployment.mmd`: Docker контейнеры, networks, volumes
- [ ] `cap_analysis.md`: Таблица сценариев сбоев и поведения системы

### ЭТАП 3: Базовая трехзвенная архитектура в Docker

**Задача 1 из практической части**

#### 3.1. Docker Compose структура
- [ ] Создать `docker-compose.yml`:
  ```yaml
  services:
    # Frontend tier
    nginx:
      - static files
      - reverse proxy
    
    # Application tier
    user-service:
      - FastAPI
    document-service:
      - FastAPI
    search-service:
      - FastAPI
    
    # Data tier
    postgres-primary:
      - PostgreSQL 16
    valkey:
      - Redis-compatible cache
  ```

#### 3.2. Базовые микросервисы (FastAPI)
- [ ] **User Service**:
  ```python
  POST /api/users/register
  POST /api/users/login
  GET /api/users/profile
  ```
- [ ] **Document Service**:
  ```python
  POST /api/documents (добавить документ)
  GET /api/documents/{id}
  GET /api/documents (список с пагинацией)
  DELETE /api/documents/{id}
  ```
- [ ] **Search Service**:
  ```python
  GET /api/search?q=query&limit=10
  GET /api/search/suggestions?q=qu
  ```

#### 3.3. Frontend
- [ ] Простой HTML/CSS/JS интерфейс:
  - Форма поиска
  - Результаты поиска с подсветкой
  - Загрузка документов
  - Логин/регистрация
- [ ] Nginx отдает статику из `/usr/share/nginx/html`

#### 3.4. Инициализация БД
- [ ] `database/init-scripts/01-init-databases.sql`:
  ```sql
  CREATE DATABASE users_db;
  CREATE DATABASE documents_db;
  CREATE DATABASE search_db;
  CREATE DATABASE audit_db;
  ```
- [ ] `02-create-schemas.sql`: таблицы для каждого сервиса
- [ ] Healthcheck endpoints для всех сервисов

### ЭТАП 4: Nginx — балансировка и кэширование

**Задача 2 из практической части**

#### 4.1. Балансировка нагрузки
- [ ] `nginx.conf`:
  ```nginx
  upstream user_backend {
      least_conn;
      server user-service-1:8000 max_fails=3 fail_timeout=30s;
      server user-service-2:8000 max_fails=3 fail_timeout=30s;
  }
  
  upstream search_backend {
      least_conn;
      server search-service-1:8000;
      server search-service-2:8000;
      server search-service-3:8000;  # 3 реплики для поиска
  }
  ```
- [ ] Масштабировать сервисы в docker-compose:
  ```yaml
  user-service:
    deploy:
      replicas: 2
  search-service:
    deploy:
      replicas: 3  # Поиск — критично
  ```

#### 4.2. Кэширование в Nginx
- [ ] `proxy_cache` для GET-запросов:
  ```nginx
  proxy_cache_path /var/cache/nginx levels=1:2 
                   keys_zone=api_cache:10m max_size=100m inactive=10m;
  
  location /api/search {
      proxy_cache api_cache;
      proxy_cache_valid 200 5m;
      proxy_cache_key "$scheme$request_method$host$request_uri$args";
      proxy_cache_bypass $http_cache_control;
      add_header X-Cache-Status $upstream_cache_status;
  }
  ```

#### 4.3. ValKey (Redis) для результатов поиска
- [ ] В Search Service:
  ```python
  cache_key = f"search:{hash(query)}"
  cached = await redis.get(cache_key)
  if cached:
      return json.loads(cached)
  
  results = await db.search(query)
  await redis.setex(cache_key, 300, json.dumps(results))  # 5 min TTL
  ```
- [ ] Интеграция ValKey в docker-compose

### ЭТАП 5: Репликация PostgreSQL

**Задача 3 из практической части**

#### 5.1. Использовать pg_auto_failover
- [ ] Адаптировать существующий `pg_auto/docker-compose.yml`:
  - Monitor node
  - Primary node (node1)
  - Standby node (node2)
- [ ] Настроить streaming replication
- [ ] Healthcheck для failover

#### 5.2. Разделение чтения/записи
- [ ] User/Document Service → пишут в Primary
- [ ] Search Service → читает из Standby (для разгрузки Primary)
- [ ] Добавить read-only connection string в env:
  ```yaml
  DATABASE_URL_WRITE: postgresql://docker:secret@pgauto-node1:5432/search_db
  DATABASE_URL_READ: postgresql://docker:secret@pgauto-node2:5432/search_db
  ```

#### 5.3. Тестирование failover
- [ ] Скрипт `scripts/test-failover.sh`:
  ```bash
  # Остановить Primary
  docker stop pgauto-node1
  # Проверить, что Standby стал Primary
  docker exec pgauto-monitor pg_autoctl show state
  # Проверить работоспособность приложения
  curl http://localhost/api/search?q=test
  ```

### ЭТАП 6: Полная микросервисная архитектура

**Задача 4 из практической части**

#### 6.1. Финализация 3+ микросервисов
- [ ] Завершить реализацию User, Document, Search Services
- [ ] Добавить межсервисное взаимодействие:
  ```python
  # В Search Service при поиске
  user_id = extract_user_from_jwt(request)
  user_quota = await user_service_client.get("/users/{user_id}/quota")
  if user_quota.exceeded:
      raise HTTPException(429, "Quota exceeded")
  ```
- [ ] Использовать httpx для async HTTP-запросов между сервисами
- [ ] Service discovery через Docker DNS (имена сервисов)

#### 6.2. API Gateway функции
- [ ] Маршрутизация:
  ```nginx
  location /api/users { proxy_pass http://user_backend; }
  location /api/documents { proxy_pass http://document_backend; }
  location /api/search { proxy_pass http://search_backend; }
  ```
- [ ] Rate limiting (ngx_http_limit_req_module):
  ```nginx
  limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
  limit_req zone=api_limit burst=20 nodelay;
  ```
- [ ] CORS headers для frontend

### ЭТАП 7: Асинхронная обработка

**Задача 5 из практической части**

#### 7.1. Выбор очереди: RabbitMQ
- [ ] Добавить RabbitMQ в docker-compose:
  ```yaml
  rabbitmq:
    image: rabbitmq:3-management
    ports:
      - "5672:5672"
      - "15672:15672"  # Management UI
  ```

#### 7.2. Очередь индексации
- [ ] Document Service при создании документа:
  ```python
  @router.post("/documents")
  async def create_document(doc: DocumentCreate):
      doc_id = await db.insert_document(doc)
      await rabbitmq.publish("indexing_queue", {"doc_id": doc_id, "content": doc.content})
      return {"id": doc_id, "status": "pending_indexing"}
  ```

#### 7.3. Indexer Worker
- [ ] `services/indexer-worker/worker.py`:
  ```python
  while True:
      message = await rabbitmq.consume("indexing_queue")
      doc = message.body
      
      # Токенизация
      tokens = tokenize(doc["content"])
      
      # Построение inverted index
      for token in tokens:
          term_id = await get_or_create_term(token)
          await db.insert_posting(term_id, doc["doc_id"], position, tf_idf)
      
      # Инвалидация кэша
      await redis.delete(f"search:*")
      
      message.ack()
  ```
- [ ] Масштабировать воркеры (3-5 реплик)

#### 7.4. Дополнительные async задачи
- [ ] Отправка email-уведомлений при завершении индексации
- [ ] Генерация thumbnails для PDF-документов
- [ ] Периодическая переиндексация старых документов

### ЭТАП 8: DNS-балансировка (симуляция)

**Задача 6 из практической части**

#### 8.1. Концепция
- [ ] Эмуляция geo-distributed deployment:
  - `eu.search.local` → EU datacenter (nginx-eu)
  - `us.search.local` → US datacenter (nginx-us)
  - `search.local` → Round Robin между EU/US

#### 8.2. Windows hosts файл
- [ ] `scripts/dns-setup.ps1` (PowerShell):
  ```powershell
  Add-Content C:\Windows\System32\drivers\etc\hosts @"
  127.0.0.1 eu.search.local
  127.0.0.1 us.search.local
  127.0.0.1 search.local
  "@
  ```
- [ ] Запуск 2 nginx на разных портах (8080, 8081)
- [ ] Round Robin через PowerShell скрипт, который переключает DNS

#### 8.3. Или dnsmasq в Docker
- [ ] Добавить dnsmasq контейнер:
  ```
  address=/search.local/172.20.0.10
  address=/search.local/172.20.0.11
  ```
- [ ] Клиенты используют dnsmasq как DNS-сервер

### ЭТАП 9: Мониторинг и логирование

**Задача 7 из практической части**

#### 9.1. Prometheus
- [ ] `monitoring/prometheus/prometheus.yml`:
  ```yaml
  scrape_configs:
    - job_name: 'nginx'
      static_configs:
        - targets: ['nginx-exporter:9113']
    
    - job_name: 'postgres'
      static_configs:
        - targets: ['postgres-exporter:9187']
    
    - job_name: 'services'
      static_configs:
        - targets: 
          - 'user-service:8000'
          - 'search-service:8000'
  ```
- [ ] Добавить exporters в docker-compose
- [ ] В FastAPI добавить `prometheus-client`:
  ```python
  from prometheus_client import Counter, Histogram
  search_requests = Counter('search_requests_total', 'Total search requests')
  search_latency = Histogram('search_latency_seconds', 'Search latency')
  ```

#### 9.2. Grafana
- [ ] Dashboards:
  - System overview: CPU, Memory, Disk, Network
  - Application metrics: RPS, Latency (P50/P95/P99), Error rate
  - Database metrics: Connections, Query time, Replication lag
  - Search-specific: Queries/sec, Cache hit rate, Index size
- [ ] Alerts:
  - High latency (P95 > 500ms)
  - High error rate (> 1%)
  - Database replication lag (> 5 sec)
  - Disk usage (> 80%)

#### 9.3. Логирование
- [ ] Структурированные логи (JSON) во всех сервисах:
  ```python
  import structlog
  log = structlog.get_logger()
  log.info("search_query", query=query, user_id=user_id, results_count=len(results), duration_ms=duration)
  ```
- [ ] Централизованный сбор: Loki + Promtail (или ELK stack)
- [ ] Retention: 30 дней

### ЭТАП 10: Резервное копирование и восстановление

**Задача 8 из практической части**

#### 10.1. Ежечасный pg_dump
- [ ] `database/backup/backup.sh`:
  ```bash
  #!/bin/bash
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  BACKUP_DIR=/backups
  
  for DB in users_db documents_db search_db audit_db; do
    pg_dump -h pgauto-node1 -U docker $DB | gzip > $BACKUP_DIR/${DB}_${TIMESTAMP}.sql.gz
  done
  
  # Удалить старые бэкапы (>7 дней)
  find $BACKUP_DIR -name "*.sql.gz" -mtime +7 -delete
  ```
- [ ] Cron в контейнере или Windows Task Scheduler на хосте:
  ```yaml
  backup-service:
    image: postgres:16
    volumes:
      - ./database/backup:/scripts
      - backup-data:/backups
    command: |
      sh -c 'echo "0 * * * * /scripts/backup.sh" | crontab - && crond -f'
  ```

#### 10.2. Симуляция сбоя и восстановление
- [ ] `scripts/test-backup-restore.sh`:
  ```bash
  # 1. Создать тестовые данные
  curl -X POST http://localhost/api/documents -d '{"title":"Test Doc"}'
  
  # 2. Сделать бэкап
  docker exec backup-service /scripts/backup.sh
  
  # 3. Симулировать сбой (удалить данные)
  docker exec pgauto-node1 psql -U docker -d documents_db -c "DROP TABLE documents;"
  
  # 4. Восстановить
  LATEST_BACKUP=$(ls -t /backups/documents_db_*.sql.gz | head -1)
  gunzip -c $LATEST_BACKUP | docker exec -i pgauto-node1 psql -U docker -d documents_db
  
  # 5. Проверить данные
  curl http://localhost/api/documents
  ```

#### 10.3. Point-in-Time Recovery (PITR) — дополнительно
- [ ] Настроить WAL archiving в PostgreSQL:
  ```ini
  wal_level = replica
  archive_mode = on
  archive_command = 'test ! -f /wal_archive/%f && cp %p /wal_archive/%f'
  ```
- [ ] Базовый бэкап + WAL files → восстановление на произвольный момент времени
- [ ] Скрипт `database/backup/pitr-restore.sh`

#### 10.4. MinIO S3 storage — дополнительно
- [ ] Добавить MinIO в docker-compose:
  ```yaml
  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: admin
      MINIO_ROOT_PASSWORD: password
  ```
- [ ] Загрузка бэкапов в S3:
  ```bash
  mc alias set myminio http://minio:9000 admin password
  mc mb myminio/backups
  mc cp /backups/*.sql.gz myminio/backups/
  ```

### ЭТАП 11: Event Sourcing для аудита

**Задача 9 из практической части**

#### 11.1. Audit Service — Event Store
- [ ] Таблица событий в `audit_db`:
  ```sql
  CREATE TABLE events (
      event_id BIGSERIAL,
      aggregate_type VARCHAR(50),  -- 'user', 'document'
      aggregate_id UUID,
      event_type VARCHAR(50),      -- 'created', 'updated', 'deleted'
      event_data JSONB,
      user_id UUID,
      timestamp TIMESTAMPTZ DEFAULT NOW(),
      PRIMARY KEY (event_id, timestamp)
  ) PARTITION BY RANGE (timestamp);
  
  -- Партиции по месяцам
  CREATE TABLE events_2025_10 PARTITION OF events
      FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
  CREATE TABLE events_2025_11 PARTITION OF events
      FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
  ```

#### 11.2. Запись событий
- [ ] В каждом сервисе после операции:
  ```python
  @router.post("/users")
  async def create_user(user: UserCreate):
      user_id = await db.insert_user(user)
      
      # Публикация события
      await audit_service.publish_event({
          "aggregate_type": "user",
          "aggregate_id": user_id,
          "event_type": "created",
          "event_data": user.dict(),
          "user_id": current_user_id
      })
      
      return {"id": user_id}
  ```
- [ ] Audit Service записывает события в БД и отправляет в Kafka/RabbitMQ

#### 11.3. Восстановление состояния из событий
- [ ] `scripts/replay-events.py`:
  ```python
  events = await db.query("SELECT * FROM events WHERE aggregate_id = $1 ORDER BY timestamp", user_id)
  
  state = {}
  for event in events:
      if event.event_type == 'created':
          state = event.event_data
      elif event.event_type == 'updated':
          state.update(event.event_data)
      elif event.event_type == 'deleted':
          state = None
  
  return state
  ```
- [ ] Endpoint в Audit Service: `GET /audit/replay/{aggregate_type}/{aggregate_id}`

#### 11.4. Шардирование по дате
- [ ] Автоматическое создание партиций:
  ```python
  # Функция в PostgreSQL
  CREATE OR REPLACE FUNCTION create_monthly_partition()
  RETURNS void AS $$
  DECLARE
      start_date DATE;
      end_date DATE;
      partition_name TEXT;
  BEGIN
      start_date := date_trunc('month', CURRENT_DATE + INTERVAL '1 month');
      end_date := start_date + INTERVAL '1 month';
      partition_name := 'events_' || to_char(start_date, 'YYYY_MM');
      
      EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF events FOR VALUES FROM (%L) TO (%L)',
                     partition_name, start_date, end_date);
  END;
  $$ LANGUAGE plpgsql;
  
  -- Cron-задача
  SELECT cron.schedule('create-partition', '0 0 1 * *', 'SELECT create_monthly_partition()');
  ```

#### 11.5. CQRS — дополнительно
- [ ] Разделение:
  - **Write Model**: User Service → пишет события в Audit DB
  - **Read Model**: Materialized view в `users_db` для быстрого чтения
  - Синхронизация через event handlers
- [ ] Преимущество: оптимизация схем для записи и чтения независимо

### ЭТАП 12: Канареечное развертывание

**Задача 10 из практической части**

#### 12.1. Две версии User Service
- [ ] `services/user-service-v1/`: текущая версия
- [ ] `services/user-service-v2/`: новая версия (например, с новым алгоритмом хэширования паролей)
- [ ] `docker-compose.canary.yml`:
  ```yaml
  user-service-v1:
    build: ./services/user-service-v1
    deploy:
      replicas: 9
  
  user-service-v2:
    build: ./services/user-service-v2
    deploy:
      replicas: 1  # 10% трафика
  ```

#### 12.2. Nginx split_clients
- [ ] `nginx.conf`:
  ```nginx
  split_clients "${remote_addr}${http_user_agent}" $backend_version {
      10%     v2;
      *       v1;
  }
  
  upstream user_v1 {
      server user-service-v1:8000;
  }
  
  upstream user_v2 {
      server user-service-v2:8000;
  }
  
  location /api/users {
      proxy_pass http://user_$backend_version;
  }
  ```

#### 12.3. Мониторинг метрик v1 vs v2
- [ ] В Prometheus отдельные job для v1 и v2
- [ ] Grafana dashboard: сравнение error rate, latency, throughput
- [ ] Алертинг: если error_rate_v2 > error_rate_v1 * 2 → откат

#### 12.4. Симуляция ошибок в v2
- [ ] Добавить в v2 код:
  ```python
  import random
  if random.random() < 0.05:  # 5% ошибок
      raise HTTPException(500, "Simulated error in v2")
  ```
- [ ] Проверить, что Grafana показывает рост ошибок

#### 12.5. Автоматический откат — дополнительно
- [ ] `scripts/monitor-canary.py`:
  ```python
  while True:
      v1_errors = prometheus.query('rate(http_errors_total{version="v1"}[5m])')
      v2_errors = prometheus.query('rate(http_errors_total{version="v2"}[5m])')
      
      if v2_errors > v1_errors * 2:
          print("High error rate in v2, rolling back...")
          os.system("docker-compose -f docker-compose.canary.yml scale user-service-v2=0")
          break
      
      time.sleep(60)
  ```

### ЭТАП 13: Индивидуальные задачи для варианта 8

#### 13.1. Описание вызовов поисковой системы
- [ ] Документ в `docs/lr4_report.md`, раздел "Вызовы и требования":
  - Индексация 100К документов за 1 час
  - Поиск с латенси P95 < 100ms
  - Поддержка сложных запросов (Boolean, фразы, fuzzy)
  - Актуальность индекса (новые документы видны за 5 сек)

#### 13.2. Детальная архитектура микросервисов
- [ ] Диаграмма `docs/architecture/microservices.mmd`:
  ```mermaid
  graph TB
      Client[Client Browser]
      DNS[DNS Round Robin]
      LB1[Nginx EU]
      LB2[Nginx US]
      
      US[User Service x2]
      DS[Document Service x2]
      SS[Search Service x3]
      IW[Indexer Worker x5]
      AS[Audit Service x1]
      
      Q[RabbitMQ]
      Cache[ValKey]
      
      DB1[(PostgreSQL Primary)]
      DB2[(PostgreSQL Standby)]
      DBA[(Audit DB)]
      
      Client --> DNS
      DNS --> LB1
      DNS --> LB2
      LB1 --> US
      LB1 --> DS
      LB1 --> SS
      
      DS -->|publish| Q
      Q --> IW
      IW --> DB1
      
      SS --> Cache
      Cache --> SS
      SS --> DB2
      
      US --> DB1
      DS --> DB1
      DB1 -.replicate.-> DB2
      
      US -->|events| AS
      DS -->|events| AS
      AS --> DBA
  ```

#### 13.3. Использование очередей
- [ ] Indexing Queue: Document Service → Indexer Workers
- [ ] Notification Queue: email, webhooks при завершении индексации
- [ ] Reindexing Queue: фоновая переиндексация старых документов

#### 13.4. DNS-балансировка по geo-зонам
- [ ] EU datacenter: Nginx + 2x Search Service (ближе к EU пользователям)
- [ ] US datacenter: Nginx + 2x Search Service (ближе к US пользователям)
- [ ] DNS возвращает IP ближайшего датацентра (в реальности GeoIP DNS)

#### 13.5. CAP-анализ для поисковой системы
- [ ] `docs/architecture/cap_analysis.md`:
  ```markdown
  # CAP-теорема для поисковой системы
  
  ## Выбранный компромисс: AP (Availability + Partition Tolerance)
  
  ### Обоснование:
  - Поиск критичен к доступности (лучше устаревшие результаты, чем ошибка)
  - Eventual consistency приемлема (новый документ может индексироваться 5-10 сек)
  - Partition tolerance необходима для geo-distributed deployment
  
  ## Сценарии:
  
  | Сбой | Поведение | CAP-компромисс |
  |------|-----------|----------------|
  | Primary DB недоступна | Поиск работает с Standby (read-only) | A сохраняется, C ослабляется |
  | Network partition EU-US | Каждый регион работает независимо | A сохраняется, C временно нарушается |
  | Задержка репликации | Пользователь не видит свой документ | Eventual consistency (acceptable) |
  | Indexer перегружен | Документы в очереди, индексация отложена | A сохраняется, C ослабляется |
  
  ## Исключения (CP):
  - User authentication: строгая консистентность (запись в Primary)
  - Document deletion: синхронное удаление из индекса
  ```

#### 13.6. Стратегия развертывания
- [ ] Blue-Green deployment:
  - Запустить новую версию параллельно (green)
  - Переключить DNS/Nginx на green
  - Держать blue для быстрого rollback
- [ ] Canary: описано в ЭТАПЕ 12
- [ ] Rolling update для не-критичных сервисов:
  ```bash
  docker-compose up -d --scale search-service=6  # 3 old + 3 new
  # проверка...
  docker-compose up -d --scale search-service=3  # только new
  ```

#### 13.7. Отказоустойчивость
- [ ] Методы:
  - PostgreSQL auto-failover (pg_auto_failover)
  - Nginx health checks + automatic upstream removal
  - RabbitMQ clustering (3 ноды)
  - Circuit breaker между сервисами (httpx retries)
  - Graceful shutdown (SIGTERM handling)
- [ ] Тестирование: `scripts/chaos-testing.sh` (останавливает случайные контейнеры)

#### 13.8. Мониторинг и логирование
- [ ] Инструменты:
  - Prometheus + Grafana (метрики)
  - Loki + Promtail (логи)
  - Jaeger (distributed tracing)
  - AlertManager (уведомления в Slack/email)
- [ ] Ключевые метрики:
  - Search QPS, P95/P99 latency
  - Cache hit rate
  - Indexing lag (очередь размер)
  - DB replication lag
  - Error rate by service

#### 13.9. Аудит событий для поисковой системы
- [ ] Важные события:
  - Document created/updated/deleted
  - Search query executed (для аналитики)
  - User login/logout
  - Index rebuilt
- [ ] Восстановление состояния:
  ```sql
  -- Восстановить документ на момент времени
  SELECT event_data FROM events
  WHERE aggregate_type = 'document'
    AND aggregate_id = '123e4567-e89b-12d3-a456-426614174000'
    AND timestamp <= '2025-10-25 12:00:00'
  ORDER BY timestamp DESC
  LIMIT 1;
  ```
- [ ] Обработка логических ошибок:
  - Баг в коде удалил документы → replay событий до бага → восстановление

#### 13.10. Поэтапное развертывание
- [ ] Описано в ЭТАПЕ 12 (Canary)
- [ ] Алгоритм:
  1. Deploy v2 с 10% трафика
  2. Мониторинг 1 час → если error_rate_v2 < 1% → OK
  3. Увеличить до 50% → мониторинг 30 мин
  4. Увеличить до 100%
  5. Удалить v1
- [ ] Откат: моментальный через изменение `split_clients` в Nginx

### ЭТАП 14: Финальная документация

#### 14.1. Письменный отчет
- [ ] `docs/lr4_report.md` структура:
  ```markdown
  # ЛР4: Проектирование высоконагруженной поисковой системы
  
  ## 1. Титульный лист
  - ФИО, группа, вариант 8
  
  ## 2. Теоретическая часть
  - 11 тем (из lr4_theory.md)
  
  ## 3. Индивидуальный вариант: Поисковая система
  - 3.1. Вызовы и требования
  - 3.2. Архитектура микросервисов (диаграммы)
  - 3.3. Использование очередей
  - 3.4. DNS-балансировка
  - 3.5. CAP-анализ
  - 3.6. Стратегия развертывания
  - 3.7. Отказоустойчивость
  - 3.8. Мониторинг
  - 3.9. Event Sourcing
  - 3.10. Канареечное развертывание
  
  ## 4. Практическая реализация
  - 4.1. Трехзвенная архитектура
  - 4.2. Nginx балансировка и кэш
  - 4.3. PostgreSQL репликация
  - 4.4. Микросервисы
  - 4.5. Асинхронная обработка
  - 4.6. DNS-симуляция
  - 4.7. Мониторинг
  - 4.8. Бэкапы
  - 4.9. Event Sourcing
  - 4.10. Canary deployment
  
  ## 5. Результаты и выводы
  
  ## 6. Ответы на контрольные вопросы
  
  ## 7. Приложения
  - Конфигурационные файлы
  - Скриншоты Grafana
  - Скриншоты тестов
  ```

#### 14.2. README.md
- [ ] Пошаговое руководство:
  ```markdown
  # Поисковая система — ЛР4
  
  ## Быстрый старт
  1. Клонировать репозиторий
  2. `docker-compose up -d`
  3. Открыть http://localhost
  
  ## Компоненты
  - Nginx: http://localhost (frontend + API gateway)
  - Grafana: http://localhost:3000 (admin/admin)
  - Prometheus: http://localhost:9090
  - RabbitMQ: http://localhost:15672 (guest/guest)
  
  ## Тестирование
  - Создать документ: `curl -X POST http://localhost/api/documents ...`
  - Поиск: `curl http://localhost/api/search?q=test`
  - Failover: `./scripts/test-failover.sh`
  - Канареечное: `docker-compose -f docker-compose.canary.yml up`
  
  ## Архитектура
  См. docs/architecture/*.mmd
  
  ## Отчет
  docs/lr4_report.md
  ```

#### 14.3. Видео-демонстрация (опционально)
- [ ] Записать скринкаст:
  - Запуск системы
  - Создание документа через UI
  - Поиск с демонстрацией кэширования
  - Failover PostgreSQL
  - Grafana метрики
  - Canary deployment

---

## Приоритеты и сроки

### Критичные (обязательные):
1. ✅ ЭТАП 0: Подготовка (DONE)
2. 🔴 ЭТАП 1: Теория (3-5 часов)
3. 🔴 ЭТАП 2: Проектирование архитектуры (2-3 часа)
4. 🔴 ЭТАП 3-6: Базовая реализация (10-15 часов)
5. 🔴 ЭТАП 9: Мониторинг (3-4 часа)
6. 🔴 ЭТАП 10: Бэкапы (2-3 часа)
7. 🔴 ЭТАП 11: Event Sourcing (4-5 часов)
8. 🔴 ЭТАП 12: Canary deployment (3-4 часа)
9. 🔴 ЭТАП 14: Документация (5-6 часов)

### Дополнительные (для высокой оценки):
- 🟡 PITR + MinIO (ЭТАП 10.3-10.4)
- 🟡 CQRS (ЭТАП 11.5)
- 🟡 Автоматический откат канареечного (ЭТАП 12.5)
- 🟡 Видео-демонстрация (ЭТАП 14.3)

### Рекомендуемый порядок:
1. Теория + проектирование (ЭТАП 1-2) → база для практики
2. Базовая система (ЭТАП 3-4) → минимально работающий прототип
3. БД репликация (ЭТАП 5) → критично для отказоустойчивости
4. Микросервисы (ЭТАП 6) → основная архитектура
5. Асинхронность (ЭТАП 7) → специфика поисковой системы
6. Мониторинг (ЭТАП 9) → необходим для следующих этапов
7. Бэкапы (ЭТАП 10) → обязательная задача
8. Event Sourcing (ЭТАП 11) → обязательная задача
9. Canary (ЭТАП 12) → обязательная задача
10. DNS-симуляция (ЭТАП 8) → можно в конце
11. Документация (ЭТАП 13-14) → параллельно с разработкой

---

## Чек-лист для сдачи

### Теория (docs/lr4_theory.md):
- [ ] 11 тем раскрыты с диаграммами и примерами
- [ ] CAP-теорема с анализом для поисковой системы

### Практика:
- [ ] ✅ Docker Compose с 10+ сервисами запускается
- [ ] ✅ Nginx балансирует между репликами сервисов
- [ ] ✅ PostgreSQL репликация Primary-Standby
- [ ] ✅ 3 микросервиса (User, Document, Search)
- [ ] ✅ RabbitMQ + Indexer Worker
- [ ] ✅ Prometheus + Grafana с дашбордами
- [ ] ✅ Скрипт бэкапа и восстановления
- [ ] ✅ Event Sourcing с партиционированием
- [ ] ✅ Canary deployment v1/v2

### Документация:
- [ ] README.md с инструкциями запуска
- [ ] docs/lr4_report.md полный отчет
- [ ] docs/architecture/*.mmd диаграммы
- [ ] Скриншоты Grafana, Prometheus, RabbitMQ
- [ ] Скрипты в scripts/

### Тестирование:
- [ ] Система запускается одной командой
- [ ] Frontend доступен и работает
- [ ] API endpoints возвращают данные
- [ ] Поиск находит документы
- [ ] Failover PostgreSQL работает
- [ ] Бэкап и восстановление работают
- [ ] Canary deployment переключается

---

## Полезные команды

```bash
# Запуск основной системы
docker-compose up -d

# Просмотр логов
docker-compose logs -f search-service

# Масштабирование
docker-compose up -d --scale search-service=5

# Проверка healthcheck
docker-compose ps

# Мониторинг ресурсов
docker stats

# Бэкап БД
docker exec backup-service /scripts/backup.sh

# Тест failover
./scripts/test-failover.sh

# Canary deployment
docker-compose -f docker-compose.canary.yml up -d

# Остановка всего
docker-compose down -v
```

---

## Итого

Этот план покрывает:
- ✅ Все 11 теоретических тем
- ✅ Все 10 практических задач
- ✅ Все 9 индивидуальных пунктов для варианта 8
- ✅ Дополнительные задания (PITR, MinIO, CQRS, автооткат)
- ✅ Специфику поисковой системы (индексация, full-text search, кэширование)

**Оценка трудозатрат:** 40-50 часов чистого времени

**Следующий шаг:** Начать с ЭТАПА 1 (теория) параллельно с ЭТАПОМ 3 (базовая реализация)
