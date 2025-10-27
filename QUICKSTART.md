# 🎯 Быстрый старт для демонстрации

## 🚀 Запуск системы

```powershell
# 1. Запуск PostgreSQL кластера
cd pg_auto
docker-compose up -d
cd ..

# 2. Запуск всех микросервисов
docker-compose up -d

# 3. Ожидание инициализации (30 сек)
Start-Sleep -Seconds 30

# 4. Проверка статуса
docker ps --format "table {{.Names}}\t{{.Status}}"
```

## 📦 Заполнение демо-данными

```powershell
# Автоматическое создание 15 документов
.\scripts\populate-demo-data.ps1
```

## 🌐 Доступ к интерфейсам

| Сервис | URL | Логин/Пароль |
|--------|-----|--------------|
| **🏠 Главная страница** | http://localhost | - |
| **⚙️ Админ-панель** | http://localhost/admin.html | - |
| **📊 Grafana** | http://localhost:3000 | admin / admin |
| **📈 Prometheus** | http://localhost:9090 | - |
| **🐰 RabbitMQ** | http://localhost:15672 | admin / admin |

## 🎨 Админ-панель функции

### Статистика в реальном времени
- **Всего документов** - количество документов в системе
- **Проиндексировано** - документы, обработанные indexer-service
- **Ожидает индексации** - новые документы в очереди
- **Пользователей** - зарегистрированные пользователи

### Быстрые действия
- 🔄 **Обновить данные** - перезагрузить статистику и список документов
- 📦 **Заполнить демо-данными** - создать 15 демонстрационных документов
- 🔍 **Переиндексировать все** - отправить все документы на индексацию
- 🗑️ **Очистить все данные** - удалить все документы (требует подтверждения)
- 📊 **Grafana** - открыть дашборды мониторинга
- 📈 **Prometheus** - открыть метрики системы
- 🐰 **RabbitMQ** - открыть управление очередями

### Добавление документов
Форма создания нового документа:
- **Заголовок** (обязательно)
- **Содержание** (обязательно)
- **Автор** (опционально)

### Список документов
Отображение всех документов с:
- Заголовком и статусом индексации
- Превью содержания (200 символов)
- Метаданными (ID, автор, дата создания)
- Кнопкой удаления

## 🧪 Проверка функциональности

### 1. Проверка API
```powershell
# Получить список документов
curl http://localhost/api/documents?limit=5

# Создать новый документ
curl -X POST http://localhost/api/documents `
  -H "Content-Type: application/json" `
  -d '{"title":"Test","content":"Test content","author":"Admin"}'

# Поиск документов
curl "http://localhost/api/search?q=PostgreSQL&limit=5"
```

### 2. Проверка Canary Deployment
```powershell
# Выполнить 10 запросов и посмотреть распределение v1/v2
.\scripts\test-canary.ps1
```

### 3. Проверка Event Sourcing
```powershell
# Проверить партицирование событий аудита
.\scripts\test-event-sourcing.ps1
```

### 4. Проверка DNS Round Robin
```powershell
# Запустить DNS балансировку
docker-compose -f docker-compose.dns.yml up -d
.\scripts\test-dns-balancing.ps1
```

## 🔍 Демонстрация в браузере

### Главная страница (http://localhost)
1. **Регистрация пользователя**
   - Email, username, пароль
   - Автоматическая аутентификация

2. **Поиск документов**
   - Введите запрос (например: "PostgreSQL", "Docker", "Nginx")
   - Отображение результатов с подсветкой
   - Метрики времени выполнения

3. **Управление документами**
   - Создание нового документа
   - Просмотр списка документов
   - Статус индексации

### Админ-панель (http://localhost/admin.html)
1. **Мониторинг в реальном времени**
   - Статистика документов
   - Статус индексации

2. **Массовые операции**
   - Заполнение демо-данными одним кликом
   - Переиндексация всех документов
   - Очистка данных

3. **CRUD операции**
   - Создание документов
   - Просмотр всех документов
   - Удаление документов

### Grafana (http://localhost:3000)
1. Войти (admin / admin)
2. Перейти в Dashboards
3. Открыть "System Monitoring"
4. Просмотреть:
   - Графики нагрузки
   - Метрики сервисов
   - Производительность PostgreSQL

### Prometheus (http://localhost:9090)
1. Перейти в Status → Targets
2. Проверить, что все endpoints UP
3. Перейти в Graph
4. Выполнить запросы:
   ```promql
   up
   http_requests_total
   document_service_requests_total
   nginx_http_requests_total
   ```

### RabbitMQ (http://localhost:15672)
1. Войти (admin / admin)
2. Перейти в Queues
3. Посмотреть очередь `indexing_queue`
4. Проверить Exchanges и Connections

## 📋 Чек-лист демонстрации

- [x] Система запущена (все контейнеры UP)
- [x] PostgreSQL кластер работает (primary + secondary)
- [x] Демо-данные загружены (15+ документов)
- [x] API Gateway отвечает (nginx healthy)
- [x] Главная страница открывается
- [x] Админ-панель доступна
- [x] Grafana показывает метрики
- [x] Prometheus собирает данные
- [x] RabbitMQ принимает сообщения
- [x] Поиск работает
- [x] Canary Deployment работает (80/20)

## 🛠️ Решение проблем

### Ошибка "502 Bad Gateway"
```powershell
# Перезапустить nginx
docker restart search-nginx-canary
Start-Sleep -Seconds 5
```

### Документы не загружаются
```powershell
# Проверить статус document-service
docker ps --filter "name=document"
docker logs search-document-service --tail 20

# Перезапустить сервис
docker restart search-document-service
```

### PostgreSQL недоступен
```powershell
# Проверить статус кластера
docker exec pgauto-node1 pg_autoctl show state

# Перезапустить кластер
cd pg_auto
docker-compose restart
cd ..
```

### "Ожидает индексации" не меняется
```powershell
# Проверить indexer-worker
docker logs search-indexer-worker --tail 20

# Проверить RabbitMQ очередь
# Открыть http://localhost:15672 → Queues → indexing_queue
```

## 🎓 Сценарий защиты

Смотрите подробный сценарий в файле `DEFENSE_GUIDE.md`:
- Последовательность демонстрации
- Команды с ожидаемыми результатами
- Ответы на типичные вопросы
- Технические детали реализации

## 📞 Полезные команды

```powershell
# Статус всех контейнеров
docker ps --format "table {{.Names}}\t{{.Status}}"

# Логи сервиса
docker logs <container_name> -f

# Перезапуск системы
docker-compose restart

# Остановка системы
docker-compose down
cd pg_auto
docker-compose down

# Полная очистка
docker-compose down -v
cd pg_auto
docker-compose down -v
```

---

**Автор:** Скрыпник Василий Александрович  
**Группа:** 211-331  
**Дата:** 27 октября 2025
