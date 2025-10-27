# 🎯 Тестирование в браузере - Памятка

## ✅ Все готово для демонстрации!

### 📊 Текущий статус системы
- ✅ 15 контейнеров работают
- ✅ 16 демо-документов загружено
- ✅ PostgreSQL кластер (primary + secondary)
- ✅ API Gateway + Canary Deployment
- ✅ Мониторинг (Prometheus + Grafana)

---

## 🌐 Открыть все интерфейсы

### 1. 🏠 Главная страница
**URL:** http://localhost

**Что тестировать:**
1. ✨ **Регистрация:**
   - Email: `test@example.com`
   - Username: `testuser`
   - Password: `123456`
   - Полное имя: `Test User`
   - → Нажать "Зарегистрироваться"

2. 🔍 **Поиск:**
   - Ввести: `PostgreSQL` → нажать "Искать"
   - Ввести: `Docker` → нажать "Искать"
   - Ввести: `RabbitMQ` → нажать "Искать"
   - Должны показаться результаты с подсветкой

3. 📄 **Управление документами:**
   - Нажать "Обновить список" в разделе документов
   - Должны появиться 16 документов
   - Проверить статусы индексации

4. ➕ **Создание документа:**
   - Заголовок: `Мой тестовый документ`
   - Содержание: `Это тестовое содержание для демонстрации`
   - Автор: `Test User`
   - → Нажать "Создать документ"

---

### 2. ⚙️ Админ-панель
**URL:** http://localhost/admin.html

**Что проверить:**
1. 📊 **Статистика** (вверху страницы):
   - Всего документов: **16**
   - Проиндексировано: **0-16** (зависит от времени)
   - Ожидает индексации: **0-16**

2. 🔄 **Быстрые действия:**
   - Нажать "🔄 Обновить данные" → обновляется статистика
   - Нажать "📊 Grafana" → открывается в новой вкладке
   - Нажать "📈 Prometheus" → открывается в новой вкладке
   - Нажать "🐰 RabbitMQ" → открывается в новой вкладке

3. ➕ **Добавить документ:**
   - Заполнить форму
   - Нажать "Создать документ"
   - Проверить, что документ появился в списке

4. 📄 **Список документов:**
   - Прокрутить вниз
   - Проверить статусы индексации
   - Попробовать удалить тестовый документ

---

### 3. 📊 Grafana
**URL:** http://localhost:3000
**Логин:** `admin` / **Пароль:** `admin`

**Что проверить:**
1. При первом входе предложит сменить пароль → **Skip**
2. Слева меню → **Dashboards** → **Browse**
3. Если есть дашборды → открыть их
4. Если нет → **Create your first dashboard**

**Метрики для добавления:**
- `up` - статус всех сервисов
- `http_requests_total` - количество запросов
- `document_service_requests_total` - запросы к document-service

---

### 4. 📈 Prometheus
**URL:** http://localhost:9090

**Что проверить:**
1. **Status → Targets:**
   - Все targets должны быть **UP** (зеленые)
   - Проверить: document-service, user-service-v1, user-service-v2, search-service

2. **Graph (запросы для демонстрации):**
   ```promql
   # Все сервисы работают
   up
   
   # HTTP запросы к сервисам
   http_requests_total
   
   # Запросы к document-service
   document_service_requests_total
   
   # Nginx метрики
   nginx_http_requests_total
   ```

3. Переключаться между **Table** и **Graph** для визуализации

---

### 5. 🐰 RabbitMQ Management
**URL:** http://localhost:15672
**Логин:** `admin` / **Пароль:** `admin`

**Что проверить:**
1. **Overview:**
   - Connections: должно быть несколько
   - Channels: активные каналы
   - Queues: должна быть `indexing_queue`

2. **Queues → indexing_queue:**
   - Ready: сообщения в очереди
   - Total: всего обработано
   - Message rates: скорость обработки

3. **Exchanges:**
   - Должны быть exchange'ы для сервисов

---

## 🧪 Быстрые API тесты в браузере

### Console (F12) в браузере на http://localhost

```javascript
// 1. Получить список документов
fetch('/api/documents?limit=5')
  .then(r => r.json())
  .then(d => console.table(d));

// 2. Создать новый документ
fetch('/api/documents', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({
    title: 'Тест из консоли',
    content: 'Контент созданный через browser console',
    author: 'Browser Dev'
  })
}).then(r => r.json()).then(d => console.log('Создан:', d));

// 3. Поиск
fetch('/api/search?q=Docker&limit=5')
  .then(r => r.json())
  .then(d => console.log('Найдено:', d));

// 4. Проверить Canary Deployment (10 запросов)
Promise.all(
  Array(10).fill().map(() => 
    fetch('/api/users').then(r => r.headers.get('X-Backend-Version'))
  )
).then(versions => {
  const v1 = versions.filter(v => v === 'v1').length;
  const v2 = versions.filter(v => v === 'v2').length;
  console.log(`v1: ${v1}, v2: ${v2}, ratio: ${v1}:${v2}`);
});
```

---

## 📋 Чек-лист демонстрации

### Перед демонстрацией:
- [ ] Все контейнеры запущены и healthy
- [ ] Демо-данные загружены (16+ документов)
- [ ] Nginx перезапущен (если были ошибки 502)
- [ ] Проверен доступ к Grafana, Prometheus, RabbitMQ

### Во время демонстрации:
- [ ] Показать главную страницу и функционал
- [ ] Показать админ-панель и статистику
- [ ] Зайти в Grafana и показать метрики
- [ ] Открыть Prometheus → Targets (все UP)
- [ ] Открыть RabbitMQ → очередь индексации
- [ ] Выполнить поиск и показать результаты
- [ ] Создать новый документ
- [ ] Показать Canary Deployment (80/20 split)

### После демонстрации:
- [ ] Показать архитектуру (docker-compose.yml)
- [ ] Объяснить Event Sourcing (audit-service)
- [ ] Продемонстрировать failover PostgreSQL
- [ ] Ответить на вопросы по технологиям

---

## 🔧 Если что-то пошло не так

### "502 Bad Gateway" на /api/documents
```powershell
docker restart search-nginx-canary
Start-Sleep -Seconds 5
```

### Документы не отображаются
```powershell
docker logs search-document-service --tail 20
docker restart search-document-service
```

### Заново заполнить демо-данными
```powershell
.\scripts\populate-demo-data.ps1
```

### Проверить статус всех сервисов
```powershell
docker ps --format "table {{.Names}}\t{{.Status}}"
```

---

## 🎓 Полезная информация

**Вариант:** 8  
**Группа:** 211-331  
**ФИО:** Скрыпник Василий Александрович

**Архитектура:**
- API Gateway: Nginx (Canary Deployment 80/20)
- Микросервисы: 5 FastAPI сервисов
- База данных: PostgreSQL (primary + secondary)
- Кеш: Valkey (Redis-compatible)
- Очереди: RabbitMQ
- Мониторинг: Prometheus + Grafana

**Требования ЛР4 (все реализованы):**
1. ✅ Репликация PostgreSQL (pg_auto_failover)
2. ✅ Canary Deployment (nginx split_clients 80/20)
3. ✅ Event Sourcing (audit-service + партицирование)
4. ✅ DNS Round Robin (docker-compose.dns.yml)
5. ✅ Rate Limiting (nginx limit_req_zone)
6. ✅ Кеширование (nginx proxy_cache + Valkey)
7. ✅ Load Balancing (nginx upstream)
8. ✅ Мониторинг (Prometheus + Grafana)
9. ✅ Асинхронная обработка (RabbitMQ + indexer)
10. ✅ Healthchecks (все сервисы)
11. ✅ Метрики (prometheus_client)
12. ✅ Graceful shutdown (FastAPI lifespan)

**Готово к защите! 🚀**
