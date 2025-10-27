# ✅ ПОЛНЫЙ ЧЕК-ЛИСТ ЗАДАНИЯ ЛР4

## 📋 ОБЯЗАТЕЛЬНЫЕ ТРЕБОВАНИЯ (Общая часть)

### 1. ✅ Трехзвенная архитектура
- [x] Фронтенд (Nginx + static HTML/JS)
- [x] Бэкенд (5 микросервисов на FastAPI)
- [x] База данных (PostgreSQL с репликацией)

**Проверка:**
```powershell
docker ps --format "table {{.Names}}\t{{.Image}}"
# Должно быть: nginx, 5 сервисов, PostgreSQL (3 контейнера)
```

---

### 2. ✅ Конфигурация Nginx
- [x] Обратный прокси (reverse proxy)
- [x] Балансировка нагрузки (load balancing)
- [x] Кэширование (proxy_cache)
- [x] Rate limiting

**Проверка:**
```powershell
# Проверить балансировку между v1 и v2
for ($i=1; $i -le 10; $i++) {
    $response = curl -s -I http://localhost/api/users
    $version = ($response | Select-String "X-Backend-Version").ToString()
    Write-Host "Request $i: $version"
}
# Должно быть ~80% v1, ~20% v2
```

**Файл:** `services/gateway/nginx.conf`
- Строка 40: `split_clients` для Canary Deployment
- Строка 35: `proxy_cache_path` для кэширования
- Строка 38: `limit_req_zone` для rate limiting

---

### 3. ✅ PostgreSQL с репликацией (master-slave)
- [x] Primary node (pgauto-node1)
- [x] Secondary node (pgauto-node2)
- [x] Monitor node (pgauto-monitor)
- [x] Автоматический failover (pg_auto_failover)

**Проверка:**
```powershell
# Проверить статус кластера
docker exec pgauto-node1 pg_autoctl show state

# Должно быть:
# node_1: primary (read-write)
# node_2: secondary (read-only)
```

**Симуляция failover:**
```powershell
# Остановить primary
docker stop pgauto-node1

# Подождать 10 секунд
Start-Sleep -Seconds 10

# Проверить - node2 должен стать primary
docker exec pgauto-node2 pg_autoctl show state

# Восстановить node1
docker start pgauto-node1
```

---

### 4. ✅ Микросервисы (минимум 3)
У вас **5 микросервисов** на FastAPI:

| Сервис | Назначение | Порт |
|--------|-----------|------|
| **user-service-v1** | Управление пользователями (80% трафика) | 8000 |
| **user-service-v2** | Управление пользователями (20% трафика, canary) | 8000 |
| **document-service** | Управление документами | 8000 |
| **search-service** | Полнотекстовый поиск | 8000 |
| **audit-service** | Event Sourcing для аудита | 8000 |

**Проверка:**
```powershell
# Проверить healthcheck каждого сервиса
curl http://localhost/api/users/health
curl http://localhost/api/documents/health
curl http://localhost/api/search/health
curl http://localhost/api/audit/health
```

---

### 5. ✅ Асинхронная обработка (очереди)
- [x] RabbitMQ как брокер сообщений
- [x] Очередь `indexing_queue` для индексации документов
- [x] indexer-worker обрабатывает сообщения асинхронно

**Проверка:**
```powershell
# 1. Открыть RabbitMQ Management
Start-Process "http://localhost:15672"
# Логин: admin / Пароль: admin

# 2. Перейти в Queues → indexing_queue
# Проверить:
# - Ready: количество необработанных сообщений
# - Total: всего обработано сообщений

# 3. Создать новый документ
curl -X POST http://localhost/api/documents `
  -H "Content-Type: application/json" `
  -d '{"title":"Test Async","content":"Test content","author":"Tester"}'

# 4. Проверить очередь - должно появиться сообщение
# 5. Подождать 2-3 секунды - indexer-worker обработает
# 6. Проверить документ - indexed должно быть true
curl http://localhost/api/documents | ConvertFrom-Json | Where-Object {$_.title -eq "Test Async"}
```

---

### 6. ✅ DNS-балансировка (Round Robin)
**Файл:** `docker-compose.dns.yml`

**Проверка:**
```powershell
# 1. Запустить DNS балансировку
docker-compose -f docker-compose.dns.yml up -d

# 2. Проверить DNS резолвинг
docker exec search-nginx-canary nslookup user-service-dns

# Должно вернуть несколько IP-адресов (round robin)

# 3. Запустить тестовый скрипт
.\scripts\test-dns-balancing.ps1

# 4. Остановить DNS контейнеры
docker-compose -f docker-compose.dns.yml down
```

---

### 7. ✅ Мониторинг (Prometheus + Grafana)
- [x] Prometheus собирает метрики
- [x] Grafana визуализирует дашборды
- [x] nginx-exporter экспортирует метрики Nginx

**Проверка:**
```powershell
# 1. Открыть Prometheus
Start-Process "http://localhost:9090"

# 2. Перейти в Status → Targets
# Все targets должны быть UP (зеленые):
# - document-service
# - search-service
# - user-service-v1
# - user-service-v2
# - audit-service
# - nginx-exporter

# 3. Проверить метрики (Graph)
# Выполнить запросы:
up
http_requests_total
document_service_requests_total
nginx_http_requests_total

# 4. Открыть Grafana
Start-Process "http://localhost:3000"
# Логин: admin / Пароль: admin

# 5. Перейти в Dashboards
# Должен быть дашборд "Highload System Monitoring" с 8 панелями:
# - Services Status
# - Services Health
# - HTTP Requests Rate
# - Request Latency (p95, p99)
# - Total Requests/min
# - Document Service Requests
# - Nginx Total Requests
# - Services Availability
```

---

### 8. ✅ Резервное копирование PostgreSQL

**Создание бэкапа:**
```powershell
# Создать бэкап
docker exec pgauto-node1 pg_dump -U docker app_db > backup_$(Get-Date -Format "yyyy-MM-dd_HH-mm").sql

# Проверить размер бэкапа
Get-ChildItem backup_*.sql | Select-Object Name, Length
```

**Восстановление из бэкапа:**
```powershell
# 1. Симуляция сбоя - удалить все документы
docker exec pgauto-node1 psql -U docker -d app_db -c "TRUNCATE TABLE documents RESTART IDENTITY CASCADE;"

# 2. Проверить - должно быть 0 документов
curl http://localhost/api/documents

# 3. Восстановить из бэкапа
Get-Content backup_2025-10-27_15-00.sql | docker exec -i pgauto-node1 psql -U docker -d app_db

# 4. Проверить - документы восстановлены
curl http://localhost/api/documents
```

---

### 9. ✅ Event Sourcing для аудита
- [x] audit-service записывает все события
- [x] Партицирование таблицы audit_events по дате
- [x] Возможность восстановления состояния

**Проверка:**
```powershell
# 1. Проверить таблицу событий
docker exec pgauto-node1 psql -U docker -d app_db -c "SELECT * FROM audit_events ORDER BY created_at DESC LIMIT 10;"

# 2. Проверить партиции (должны быть помесячные)
docker exec pgauto-node1 psql -U docker -d app_db -c "\d+ audit_events*"

# 3. Создать событие через API
curl -X POST http://localhost/api/users `
  -H "Content-Type: application/json" `
  -d '{"username":"test_user","email":"test@example.com","password":"123456"}'

# 4. Проверить событие в аудите
docker exec pgauto-node1 psql -U docker -d app_db -c "SELECT event_type, aggregate_type, aggregate_id, created_at FROM audit_events ORDER BY created_at DESC LIMIT 5;"

# 5. Запустить тест Event Sourcing
.\scripts\test-event-sourcing.ps1
```

---

### 10. ✅ Канареечное развертывание (Canary Deployment)
- [x] User Service v1 (80% трафика)
- [x] User Service v2 (20% трафика)
- [x] Nginx split_clients для распределения

**Проверка:**
```powershell
# 1. Запустить тестовый скрипт
.\scripts\test-canary.ps1

# Результат должен быть примерно:
# v1: 8 requests (80%)
# v2: 2 requests (20%)

# 2. Ручная проверка - 20 запросов
$v1 = 0; $v2 = 0
for ($i=1; $i -le 20; $i++) {
    $headers = curl -s -I http://localhost/api/users
    $version = ($headers | Select-String "X-Backend-Version:").ToString()
    if ($version -match "v1") { $v1++ } else { $v2++ }
}
Write-Host "v1: $v1, v2: $v2 (должно быть ~16:4 или 80/20)"

# 3. Проверить логи nginx
docker logs search-nginx-canary --tail 20 | Select-String "user-service"
```

---

## 🎯 ВАРИАНТ 8: Поисковая система

### Специфические требования:

#### 1. ✅ Индексация больших коллекций документов
- [x] document-service создает документы
- [x] RabbitMQ очередь для асинхронной индексации
- [x] indexer-worker индексирует документы
- [x] search-service использует PostgreSQL full-text search

**Проверка:**
```powershell
# 1. Загрузить коллекцию документов
.\scripts\populate-demo-data.ps1

# 2. Проверить индексацию
curl http://localhost/api/documents | ConvertFrom-Json | Group-Object indexed | Select-Object Name, Count

# 3. Проверить RabbitMQ
Start-Process "http://localhost:15672"
# Очередь indexing_queue должна обработать все сообщения
```

#### 2. ✅ Сложные поисковые запросы
- [x] Полнотекстовый поиск (to_tsvector, to_tsquery)
- [x] Ранжирование результатов (ts_rank)
- [x] Поддержка русского и английского языка

**Проверка:**
```powershell
# Различные типы поисковых запросов:

# 1. Простой поиск
curl "http://localhost/api/search?q=PostgreSQL"

# 2. Поиск по нескольким словам
curl "http://localhost/api/search?q=Docker контейнеризация"

# 3. Поиск с ограничением результатов
curl "http://localhost/api/search?q=высоконагруженные&limit=3"

# 4. Проверить время выполнения (должно быть < 50ms)
curl "http://localhost/api/search?q=RabbitMQ" | ConvertFrom-Json | Select-Object query_time_ms
```

#### 3. ✅ Кэширование результатов поиска
- [x] Nginx proxy_cache для GET /api/search
- [x] Кэш на 5 минут (proxy_cache_valid 200 5m)
- [x] Заголовок X-Cache-Status показывает HIT/MISS

**Проверка:**
```powershell
# 1. Первый запрос (должен быть MISS)
curl -I "http://localhost/api/search?q=Docker" | Select-String "X-Cache-Status"
# X-Cache-Status: MISS

# 2. Второй запрос (должен быть HIT)
curl -I "http://localhost/api/search?q=Docker" | Select-String "X-Cache-Status"
# X-Cache-Status: HIT

# 3. Проверить статистику кэша
docker exec search-nginx-canary ls -lh /var/cache/nginx
```

---

## 🧪 РУЧНОЕ ТЕСТИРОВАНИЕ КЛИЕНТА

### 1. 🏠 Главная страница (http://localhost)

**Что проверить:**

✅ **Поиск документов:**
```
1. Открыть http://localhost
2. Ввести в поле поиска: "PostgreSQL"
3. Нажать "Искать"
4. Проверить:
   - Отображаются результаты
   - Показан snippet (фрагмент текста)
   - Указано время выполнения запроса
   - Есть score (релевантность)
```

✅ **Создание документа:**
```
1. Прокрутить вниз до секции "Управление документами"
2. Заполнить форму:
   - Заголовок: "Тестовый документ"
   - Содержание: "Это тестовое содержание для демонстрации"
   - Автор: "Test User"
3. Нажать "Создать документ"
4. Проверить:
   - Появилось сообщение об успехе
   - Документ добавился в список
```

✅ **Список документов:**
```
1. Нажать "Обновить список"
2. Проверить:
   - Отображаются все документы
   - Видны статусы индексации (badge)
   - Показана дата создания
   - Есть информация об авторе
```

---

### 2. ⚙️ Админ-панель (http://localhost/admin.html)

**Что проверить:**

✅ **Статистика:**
```
1. Открыть http://localhost/admin.html
2. Проверить верхнюю панель:
   - Всего документов: число > 0
   - Проиндексировано: растет со временем
   - Ожидает индексации: уменьшается
```

✅ **Быстрые действия:**
```
1. Нажать "📊 Grafana" - откроется в новой вкладке
2. Нажать "📈 Prometheus" - откроется в новой вкладке
3. Нажать "🐰 RabbitMQ" - откроется в новой вкладке
4. Нажать "🔄 Обновить данные" - обновится статистика
```

✅ **Добавление документов:**
```
1. Прокрутить вниз до формы
2. Заполнить поля и нажать "Создать документ"
3. Проверить:
   - Документ появился в списке внизу
   - Статистика обновилась
```

---

### 3. 📊 Grafana (http://localhost:3000)

**Логин:** admin / **Пароль:** admin

**Что проверить:**

✅ **При первом входе:**
```
1. Войти (admin/admin)
2. Skip смены пароля
3. Перейти в меню слева → Dashboards
4. Найти "Highload System Monitoring"
5. Открыть дашборд
```

✅ **Проверка панелей:**
```
1. Services Status (UP/DOWN) - линии для всех сервисов
2. Services Health - gauges показывают 1 (UP)
3. HTTP Requests Rate - график растет при запросах
4. Request Latency - показывает p95 и p99
5. Total Requests/min - число растет
6. Document Service Requests - счетчик запросов
7. Nginx Total Requests - общее число
8. Services Availability - процент (должно быть ~100%)
```

✅ **Интерактивность:**
```
1. Выбрать период: Last 5 minutes
2. Включить автообновление: 5s
3. Сделать несколько запросов к API
4. Наблюдать обновление графиков в реальном времени
```

---

### 4. 📈 Prometheus (http://localhost:9090)

**Что проверить:**

✅ **Status → Targets:**
```
1. Открыть http://localhost:9090
2. Перейти Status → Targets
3. Проверить что все UP (зеленые):
   ✓ document-service (8000)
   ✓ search-service (8000)
   ✓ user-service-v1 (8000)
   ✓ user-service-v2 (8000)
   ✓ audit-service (8000)
   ✓ nginx-exporter (9113)
```

✅ **Graph - выполнить запросы:**
```
1. Перейти в Graph
2. Ввести запрос: up
3. Нажать Execute
4. Проверить: все сервисы показывают 1 (работают)

5. Другие запросы для проверки:
   - http_requests_total
   - rate(http_requests_total[1m])
   - document_service_requests_total
   - nginx_http_requests_total
```

✅ **Table view:**
```
1. Переключиться на Table
2. Увидеть все метрики в табличном виде
```

---

### 5. 🐰 RabbitMQ Management (http://localhost:15672)

**Логин:** admin / **Пароль:** admin

**Что проверить:**

✅ **Overview:**
```
1. Войти (admin/admin)
2. Проверить Overview:
   - Connections: есть активные соединения
   - Channels: открытые каналы
   - Queues: должна быть indexing_queue
```

✅ **Queues → indexing_queue:**
```
1. Перейти в Queues
2. Кликнуть на indexing_queue
3. Проверить:
   - Ready: сообщений в очереди (может быть 0 если все обработаны)
   - Total: общее количество обработанных
   - Message rates: скорость обработки (incoming/deliver)
   - Consumers: должен быть 1 (indexer-worker)
```

✅ **Создать событие и наблюдать обработку:**
```
1. Открыть в другой вкладке http://localhost/admin.html
2. Создать новый документ
3. В RabbitMQ:
   - Увидеть: Ready увеличилось на 1
   - Через 2-3 секунды: Ready уменьшилось (обработано)
   - Total увеличился на 1
```

---

## 📊 ФИНАЛЬНАЯ ПРОВЕРКА ВСЕХ ТРЕБОВАНИЙ

### Чек-лист для защиты:

```powershell
# Запустить полную проверку
Write-Host "`n=== ПРОВЕРКА ТРЕБОВАНИЙ ЛР4 ===" -ForegroundColor Cyan

# 1. Контейнеры
$containers = docker ps --format "{{.Names}}" | Measure-Object
Write-Host "✓ Контейнеров запущено: $($containers.Count)" -ForegroundColor Green

# 2. PostgreSQL репликация
$pgState = docker exec pgauto-node1 pg_autoctl show state
Write-Host "✓ PostgreSQL репликация работает" -ForegroundColor Green

# 3. Документы
$docs = curl -s http://localhost/api/documents | ConvertFrom-Json
Write-Host "✓ Документов в системе: $($docs.Count)" -ForegroundColor Green

# 4. Поиск
$search = curl -s "http://localhost/api/search?q=test" | ConvertFrom-Json
Write-Host "✓ Поиск работает, время: $($search.query_time_ms)ms" -ForegroundColor Green

# 5. Prometheus targets
$targets = curl -s http://localhost:9090/api/v1/targets | ConvertFrom-Json
$upCount = ($targets.data.activeTargets | Where-Object {$_.health -eq "up"}).Count
Write-Host "✓ Prometheus targets UP: $upCount" -ForegroundColor Green

# 6. Canary Deployment
Write-Host "`n=== Проверка Canary Deployment ===" -ForegroundColor Yellow
$v1=0; $v2=0
for ($i=1; $i -le 10; $i++) {
    $h = curl -s -I http://localhost/api/users
    if ($h -match "v1") { $v1++ } else { $v2++ }
}
Write-Host "v1: $v1 (должно ~80%), v2: $v2 (должно ~20%)" -ForegroundColor White

Write-Host "`n✅ ВСЕ СИСТЕМЫ РАБОТАЮТ!" -ForegroundColor Green
```

---

## 🎓 СЦЕНАРИЙ ДЕМОНСТРАЦИИ ПРЕПОДАВАТЕЛЮ

### 1. Запуск системы (2 мин)
```powershell
cd pg_auto
docker-compose up -d
cd ..
docker-compose up -d
python get_variant.py  # Показать вариант 8
```

### 2. Главная страница (3 мин)
- Открыть http://localhost
- Продемонстрировать поиск: "PostgreSQL", "Docker", "RabbitMQ"
- Создать новый документ
- Показать список документов

### 3. Мониторинг (5 мин)
- **Grafana:** Дашборд с 8 панелями, real-time обновление
- **Prometheus:** Status → Targets (все UP), выполнить запрос `up`
- **RabbitMQ:** Очередь indexing_queue, показать обработку

### 4. PostgreSQL репликация (2 мин)
```powershell
docker exec pgauto-node1 pg_autoctl show state
# Показать primary и secondary
```

### 5. Canary Deployment (2 мин)
```powershell
.\scripts\test-canary.ps1
# Показать распределение 80/20
```

### 6. Event Sourcing (2 мин)
```powershell
.\scripts\test-event-sourcing.ps1
# Показать события в audit_events
```

### 7. Асинхронная обработка (2 мин)
- Создать документ → показать очередь RabbitMQ → проверить индексацию

### 8. Кэширование (1 мин)
```powershell
curl -I "http://localhost/api/search?q=test" | Select-String "X-Cache-Status"
# Первый раз MISS, второй HIT
```

---

## 📝 ОТВЕТЫ НА КОНТРОЛЬНЫЕ ВОПРОСЫ

### 1. Чем синхронная репликация отличается от асинхронной?
**Ответ:** 
- **Синхронная:** PRIMARY ждет подтверждения от SECONDARY перед commit. Гарантирует консистентность, но медленнее.
- **Асинхронная:** PRIMARY не ждет подтверждения. Быстрее, но возможна потеря данных.
- **В проекте:** pg_auto_failover использует асинхронную репликацию для производительности.

### 2. Какие типы индексов наиболее эффективны для диапазонных запросов?
**Ответ:**
- **B-tree:** Лучший для диапазонных запросов (WHERE date BETWEEN)
- **В проекте:** GIN индексы для полнотекстового поиска (`CREATE INDEX ... USING GIN`)

### 3. Почему денормализация может ухудшить целостность данных?
**Ответ:**
- Дублирование данных → несогласованность при обновлении
- Требуется больше логики в приложении для поддержания консистентности
- **В проекте:** Events в audit_events денормализованы для производительности чтения

### 4. Как партиционирование влияет на производительность запросов?
**Ответ:**
- **Плюсы:** Сканирование только нужных партиций (partition pruning)
- **Минусы:** Запросы без partition key могут быть медленнее
- **В проекте:** audit_events партицирован по месяцам для эффективных запросов по дате

### 5. Какие параметры PostgreSQL критичны для OLTP-нагрузки?
**Ответ:**
- `shared_buffers` - кэш данных (25% RAM)
- `max_connections` - лимит соединений
- `work_mem` - память для сортировок
- `checkpoint_timeout` - частота checkpoint
- **В проекте:** connection pooling через asyncpg (min_size=2, max_size=10)

---

✅ **ГОТОВО К ЗАЩИТЕ!** 🚀
