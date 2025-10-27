# ЛР4: Проектирование высоконагруженной поисковой системы

**Вариант 8: Поисковая система**  
**Студент:** Скрыпник Василий Александрович  
**Группа:** 211-331  
**Статус:** ✅ **ЗАВЕРШЕНО НА 100%**

---

## 🎯 ДЛЯ ЗАЩИТЫ

**📄 Основные документы:**
- **[Документ для защиты](docs/lr4_defense.md)** - полное описание проекта с ответами на вопросы
- **[Шпаргалка](docs/lr4_quick_reference.md)** - быстрая справка для демонстрации (5 минут)
- **[Теория](docs/lr4_theory.md)** - 12 тем (1259 строк)
- **[Итоговый отчёт](docs/lr4_report.md)** - результаты выполнения всех заданий

**🚀 Быстрая демонстрация:**
```powershell
# 1. Проверка PostgreSQL кластера
cd pg_auto; docker exec -it pgauto-monitor pg_autoctl show state

# 2. Тест Backup/Restore
cd ..; .\scripts\test-backup-restore.ps1

# 3. Тест Canary Deployment
.\scripts\test-canary.ps1

# 4. Открыть мониторинг
# Prometheus: http://localhost:9090
# Grafana: http://localhost:3000 (admin/admin)
```

---

## 📋 Содержание

- [Быстрый старт](#-быстрый-старт)
- [Архитектура](#-архитектура)
- [Тестирование](#-тестирование)
- [Мониторинг](#-мониторинг)
- [Документация](#-документация)
- [Выполненные задания](#-выполненные-задания)

## Описание

Высоконагруженная распределённая поисковая система с микросервисной архитектурой, реализующая:
- ✅ Трёхзвенную архитектуру (Frontend, Application, Database)
- ✅ Горизонтальное масштабирование сервисов
- ✅ PostgreSQL репликацию (Primary-Standby) с автоматическим failover
- ✅ Балансировку нагрузки через Nginx
- ✅ Кэширование (Nginx + ValKey/Redis)
- ✅ Асинхронную индексацию через RabbitMQ
- ✅ Event Sourcing для аудита с партиционированием
- ✅ Мониторинг (Prometheus + Grafana)
- ✅ Полнотекстовый поиск с инвертированным индексом

## Архитектура

### Микросервисы
- **User Service** (2 реплики): аутентификация и управление пользователями
- **Document Service** (2 реплики): CRUD операции с документами
- **Search Service** (3 реплики): полнотекстовый поиск с кэшированием
- **Indexer Worker** (3 реплики): асинхронная индексация документов
- **Audit Service** (1 реплика): Event Sourcing для аудита всех операций

### Инфраструктура
- **Nginx**: API Gateway, балансировка нагрузки, кэширование, отдача frontend
- **PostgreSQL**: Primary + Standby с pg_auto_failover
- **ValKey (Redis)**: кэш результатов поиска и сессий
- **RabbitMQ**: очередь задач для индексации
- **Prometheus + Grafana**: мониторинг метрик
- **Exporters**: postgres, redis, nginx

## Быстрый старт

### Предварительные требования
- Docker Desktop 20.10+
- Docker Compose 2.0+
- 8 GB RAM минимум
- 20 GB свободного места

### Запуск системы

```powershell
# 1. Клонировать репозиторий
git clone https://github.com/Basil-AS/highload-systems.git
cd highload-systems

# 2. Переключиться на ветку lr4
git checkout lr4

# 3. Запустить все сервисы
docker-compose up -d

# 4. Проверить статус (ожидать ~1-2 минуты для инициализации)
docker-compose ps

# 5. Проверить логи
docker-compose logs -f
```

### Доступ к интерфейсам

| Сервис | URL | Credentials |
|--------|-----|-------------|
| **Frontend** | http://localhost | - |
| **Grafana** | http://localhost:3000 | admin / admin |
| **Prometheus** | http://localhost:9090 | - |
| **RabbitMQ Management** | http://localhost:15672 | admin / admin |

### Проверка работоспособности

```powershell
# Проверить здоровье всех сервисов
curl http://localhost/health

# Создать тестового пользователя
curl -X POST http://localhost/api/users/register `
  -H "Content-Type: application/json" `
  -d '{\"name\":\"Test User\",\"email\":\"test@example.com\",\"password\":\"password123\"}'

# Создать тестовый документ
curl -X POST http://localhost/api/documents `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer YOUR_TOKEN" `
  -d '{\"title\":\"Test Document\",\"content\":\"This is a test document for search indexing\"}'

# Выполнить поиск
curl "http://localhost/api/search?q=test&limit=10"
```

## Основные функции

### 1. Регистрация и аутентификация
- Регистрация пользователей с хэшированием паролей
- JWT токены для авторизации
- Сессии в Redis

### 2. Управление документами
- Создание, чтение, обновление, удаление документов
- Автоматическая отправка в очередь индексации
- Привязка документов к пользователям

### 3. Полнотекстовый поиск
- Инвертированный индекс (terms + postings)
- Токенизация контента
- Кэширование результатов (TTL 5 мин)
- Поддержка сложных запросов

### 4. Асинхронная индексация
- RabbitMQ очередь для задач
- 3 воркера для параллельной обработки
- Построение инвертированного индекса
- TF-IDF ранжирование

### 5. Event Sourcing
- Запись всех изменений как событий
- Партиционирование по датам
- Восстановление состояния (replay)
- CQRS паттерн (опционально)

## Масштабирование

### Горизонтальное масштабирование сервисов

```powershell
# Увеличить количество Search Service до 5 реплик
docker-compose up -d --scale search-service-1=2 --scale search-service-2=2 --scale search-service-3=2

# Увеличить количество Indexer Workers до 5
docker-compose up -d --scale indexer-worker-1=2 --scale indexer-worker-2=2
```

### Вертикальное масштабирование БД

Отредактировать `docker-compose.yml`:
```yaml
postgres-primary:
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 2G
```

## Отказоустойчивость

### Тестирование Failover PostgreSQL

```powershell
# Скрипт для тестирования failover
.\scripts\test-failover.ps1

# Или вручную:
# 1. Остановить Primary
docker stop postgres-primary

# 2. Проверить статус (Standby должен стать Primary)
docker exec postgres-monitor pg_autoctl show state

# 3. Проверить работоспособность
curl "http://localhost/api/search?q=test"

# 4. Перезапустить Primary (станет Standby)
docker start postgres-primary
```

### Тестирование отказа сервисов

```powershell
# Остановить один из Search Service
docker stop search-service-2

# Проверить, что поиск продолжает работать
curl "http://localhost/api/search?q=test"

# Вернуть сервис
docker start search-service-2
```

## Резервное копирование

### Бэкап баз данных

```powershell
# Запустить бэкап вручную
docker exec postgres-primary pg_dump -U postgres users_db | gzip > backup_users_$(Get-Date -Format "yyyyMMdd_HHmmss").sql.gz

# Или использовать скрипт
.\database\backup\backup.ps1
```

### Восстановление из бэкапа

```powershell
# Восстановить базу данных
gunzip -c backup_users_20251026_120000.sql.gz | docker exec -i postgres-primary psql -U postgres -d users_db

# Или использовать скрипт
.\database\backup\restore.ps1 backup_users_20251026_120000.sql.gz
```

## Мониторинг

### Grafana Dashboards

После входа в Grafana (http://localhost:3000):

1. **System Overview**
   - CPU, Memory, Disk, Network для всех контейнеров
   - Общее состояние кластера

2. **Application Metrics**
   - Requests Per Second (RPS) по сервисам
   - Latency (P50, P95, P99)
   - Error Rate

3. **Database Metrics**
   - Connections, Transactions
   - Query time, Slow queries
   - Replication lag

4. **Search Metrics**
   - Search queries/sec
   - Cache hit rate
   - Index size, Indexing rate

### Prometheus Queries

```promql
# RPS по сервисам
rate(http_requests_total[5m])

# P95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Error rate
rate(http_requests_total{status=~"5.."}[5m])

# Cache hit rate
rate(redis_keyspace_hits_total[5m]) / (rate(redis_keyspace_hits_total[5m]) + rate(redis_keyspace_misses_total[5m]))
```

## Канареечное развертывание

### Развертывание новой версии

```powershell
# 1. Запустить канареечную конфигурацию
docker-compose -f docker-compose.canary.yml up -d

# 2. 10% трафика направляется на v2 через Nginx split_clients

# 3. Мониторить метрики в Grafana
# Сравнить error_rate и latency v1 vs v2

# 4. Если всё ок — увеличить трафик до 100%
# Отредактировать nginx.conf: split_clients 100% v2

# 5. Откат при ошибках
docker-compose -f docker-compose.canary.yml down
docker-compose up -d
```

## Тестирование производительности

### Нагрузочное тестирование

```powershell
# Установить Apache Bench (встроен в Windows 10+)
# Или использовать скрипт для генерации нагрузки

# Тест поиска (1000 запросов, 10 параллельных)
ab -n 1000 -c 10 "http://localhost/api/search?q=test"

# Или использовать Python скрипт
python .\scripts\load-test.py --requests 10000 --concurrency 50
```

### Ожидаемые показатели

- **Search Latency**: P95 < 100ms
- **Throughput**: > 1000 RPS
- **Error Rate**: < 0.1%
- **Cache Hit Rate**: > 70%

## Структура проекта

```
highload-systems/
├── docker-compose.yml              # Основная конфигурация
├── docker-compose.canary.yml       # Канареечное развертывание
├── get_variant.py                  # Скрипт определения варианта
├── README.md                       # Этот файл
│
├── services/
│   ├── gateway/                    # Nginx (Frontend + API Gateway)
│   │   ├── Dockerfile
│   │   ├── nginx.conf
│   │   └── static/                 # Frontend HTML/CSS/JS
│   ├── user-service/               # Микросервис пользователей
│   ├── document-service/           # Микросервис документов
│   ├── search-service/             # Микросервис поиска
│   ├── indexer-worker/             # Воркер индексации
│   └── audit-service/              # Сервис аудита
│
├── database/
│   ├── init-scripts/               # SQL скрипты инициализации
│   │   └── 01-init-databases.sql
│   └── backup/                     # Скрипты бэкапа
│       ├── backup.ps1
│       └── restore.ps1
│
├── monitoring/
│   ├── prometheus/
│   │   └── prometheus.yml
│   └── grafana/
│       └── dashboards/
│
├── scripts/
│   ├── test-failover.ps1           # Тест отказоустойчивости
│   ├── load-test.py                # Нагрузочное тестирование
│   └── deploy.ps1                  # Скрипт развертывания
│
└── docs/
    ├── lr4_plan.md                 # План выполнения
    ├── lr4_theory.md               # Теоретическая часть
    ├── lr4_report.md               # Итоговый отчет
    └── architecture/               # Диаграммы архитектуры
        ├── high_level.mmd
        ├── microservices.mmd
        └── cap_analysis.md
```

## Устранение неполадок

### Сервисы не запускаются

```powershell
# Проверить логи
docker-compose logs

# Пересоздать контейнеры
docker-compose down -v
docker-compose up -d --build
```

### База данных не инициализируется

```powershell
# Удалить volumes и пересоздать
docker-compose down -v
docker volume prune -f
docker-compose up -d
```

### Медленный поиск

```powershell
# Проверить кэш
docker exec valkey redis-cli INFO stats

# Проверить индекс
docker exec postgres-primary psql -U postgres -d search_db -c "SELECT COUNT(*) FROM terms;"
```

## Контрольные вопросы

1. **Чем синхронная репликация отличается от асинхронной?**
   - Синхронная: Primary ждёт подтверждения записи на Standby (CP), асинхронная: не ждёт (AP)

2. **Какие типы индексов наиболее эффективны для диапазонных запросов?**
   - B-tree индексы, для full-text — GIN/GiST

3. **Почему денормализация может ухудшить целостность данных?**
   - Дублирование данных → сложность обновления → аномалии

4. **Как партиционирование влияет на производительность запросов?**
   - Уменьшает объём сканирования → быстрее, но усложняет JOIN

5. **Какие параметры PostgreSQL критичны для OLTP-нагрузки?**
   - `shared_buffers`, `work_mem`, `max_connections`, `checkpoint_timeout`

## Дополнительные ресурсы

- [Документация по проекту](docs/lr4_report.md)
- [Теоретическая часть](docs/lr4_theory.md)
- [Диаграммы архитектуры](docs/architecture/)
- [План выполнения](docs/lr4_plan.md)

## Автор

**Скрыпник Василий Александрович**  
Группа 211-331  
Университет ИТМО  
2025

## Лицензия

MIT License — для учебных целей
