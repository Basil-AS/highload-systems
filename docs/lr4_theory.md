# ЛР4: Теоретическая часть

**Студент:** Скрыпник Василий Александрович  
**Группа:** 211-331  
**Вариант:** 8 — Поисковая система

---

## Содержание

1. [Монолитные и сервис-ориентированные архитектуры](#1-монолитные-и-сервис-ориентированные-архитектуры)
2. [Горизонтальное масштабирование](#2-горизонтальное-масштабирование)
3. [Трёхзвенная архитектура](#3-трёхзвенная-архитектура)
4. [Обработка запросов фронтендом и бэкендом](#4-обработка-запросов-фронтендом-и-бэкендом)
5. [Кэширование и отдача статики](#5-кэширование-и-отдача-статики)
6. [Вычисления на стороне клиента](#6-вычисления-на-стороне-клиента)
7. [Масштабирование фронтенда и бэкенда](#7-масштабирование-фронтенда-и-бэкенда)
8. [DNS-балансировка (Round Robin DNS)](#8-dns-балансировка-round-robin-dns)
9. [Отказоустойчивость](#9-отказоустойчивость)
10. [Масштабирование баз данных](#10-масштабирование-баз-данных)
11. [Надёжность и резервирование](#11-надёжность-и-резервирование)

---

## 1. Монолитные и сервис-ориентированные архитектуры

### 1.1. Определения

**Монолитная архитектура** — приложение развёрнуто как единый исполняемый модуль, все компоненты тесно связаны и работают в одном процессе.

```
┌────────────────────────────────┐
│      Monolithic Application    │
│  ┌──────────────────────────┐  │
│  │    User Interface        │  │
│  ├──────────────────────────┤  │
│  │    Business Logic        │  │
│  │  - User Management       │  │
│  │  - Document Management   │  │
│  │  - Search                │  │
│  ├──────────────────────────┤  │
│  │    Data Access Layer     │  │
│  └──────────────────────────┘  │
│            ↓                   │
│       ┌──────────┐             │
│       │ Database │             │
│       └──────────┘             │
└────────────────────────────────┘
```

**Сервис-ориентированная архитектура (SOA/Microservices)** — приложение разделено на независимые сервисы, каждый отвечает за свою бизнес-функцию и может разрабатываться/развёртываться отдельно.

```
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│    User     │   │  Document   │   │   Search    │
│   Service   │   │   Service   │   │   Service   │
│             │   │             │   │             │
│  ┌───────┐  │   │  ┌───────┐  │   │  ┌───────┐  │
│  │Users  │  │   │  │Docs   │  │   │  │Index  │  │
│  │  DB   │  │   │  │  DB   │  │   │  │  DB   │  │
│  └───────┘  │   │  └───────┘  │   │  └───────┘  │
└─────────────┘   └─────────────┘   └─────────────┘
       ↑                 ↑                 ↑
       └─────────────────┴─────────────────┘
                  API Gateway
```

### 1.2. Сравнение

| Аспект | Монолит | Микросервисы |
|--------|---------|--------------|
| **Развёртывание** | Одно приложение | Множество независимых сервисов |
| **Масштабирование** | Вертикальное (весь монолит) | Горизонтальное (каждый сервис отдельно) |
| **Технологический стек** | Единый для всего приложения | Разный для каждого сервиса |
| **Тестирование** | Проще (один процесс) | Сложнее (интеграционное тестирование) |
| **Сложность разработки** | Низкая на старте | Высокая (распределённая система) |
| **Fault isolation** | Один сбой → весь монолит падает | Сбой изолирован в одном сервисе |
| **Производительность** | Быстрые вызовы (in-process) | Накладные расходы на сеть |
| **Time to market** | Быстрый старт, медленные изменения | Медленный старт, быстрые изменения |

### 1.3. Преимущества монолитной архитектуры

1. **Простота разработки**
   - Один репозиторий, одна кодовая база
   - Привычные паттерны разработки
   - Простая отладка (один процесс)

2. **Низкая latency**
   - Вызовы функций in-process (наносекунды)
   - Нет накладных расходов на сериализацию/десериализацию
   - Транзакции ACID в рамках одной БД

3. **Простое развёртывание**
   - Один артефакт (JAR, EXE, Docker image)
   - Один сервер (на старте)
   - Простой CI/CD pipeline

4. **Лучше для малых команд**
   - Не требует сложной координации
   - Меньше overhead на коммуникацию
   - Проще onboarding новых разработчиков

**Пример:** Блог, CMS, internal tool с < 10K users

### 1.4. Недостатки монолитной архитектуры

1. **Ограничение масштабирования**
   - Нельзя масштабировать отдельные части
   - Весь монолит работает на одном сервере
   - Дорого масштабировать вертикально (CPU, RAM)

2. **Длительные deployment**
   - Изменение одной строки → пересборка всего приложения
   - Долгий старт (особенно на Java/Spring)
   - Риск downtime при deployment

3. **Технологическая блокировка**
   - Сложно перейти на другой язык/фреймворк
   - Legacy код накапливается
   - Зависимость от версий библиотек

4. **Отказоустойчивость**
   - Один bug → весь монолит падает
   - Memory leak в одном модуле → OOM для всего приложения
   - Нет fault isolation

**Пример проблемы:** E-commerce монолит с 1M users, search индексация нагружает CPU → вся система тормозит, включая checkout.

### 1.5. Преимущества микросервисной архитектуры

1. **Независимое масштабирование**
   - Поисковый сервис → 10 реплик
   - User Service → 2 реплики
   - Оптимальное использование ресурсов

2. **Technology diversity**
   - Search Service на Python + Elasticsearch
   - User Service на Go
   - Document Service на Java

3. **Fault isolation**
   - Сбой Document Service не влияет на Search
   - Circuit breaker может изолировать падающий сервис
   - Graceful degradation

4. **Быстрые релизы**
   - Изменение в Search Service → deploy только этого сервиса
   - Параллельная разработка командами
   - Continuous deployment для каждого сервиса

5. **Организационные преимущества**
   - Команды владеют своими сервисами
   - Автономия в принятии решений
   - Меньше конфликтов в Git

**Пример:** Netflix, Amazon, Uber — тысячи микросервисов

### 1.6. Недостатки микросервисной архитектуры

1. **Операционная сложность**
   - Нужен Kubernetes/Docker Swarm для оркестрации
   - Service mesh (Istio) для управления трафиком
   - Distributed tracing (Jaeger) для отладки
   - Централизованное логирование (ELK)

2. **Network latency**
   - Вызов функции: 1 наносекунда
   - HTTP call: 1-10 миллисекунд (в 1 млн раз медленнее!)
   - Много микросервисов → latency накапливается

3. **Eventual consistency**
   - Нет ACID транзакций между сервисами
   - Saga pattern для распределённых транзакций
   - Сложная отладка race conditions

4. **Data duplication**
   - Каждый сервис имеет свою БД
   - Синхронизация данных через events
   - Риск inconsistency

5. **Testing сложность**
   - Unit tests просты
   - Integration tests требуют поднятия всех сервисов
   - End-to-end tests хрупкие и медленные

**Пример проблемы:** Создание заказа требует вызовов:
```
User Service (auth) → Product Service (check stock) → 
→ Payment Service (charge) → Shipping Service (create label) → 
→ Notification Service (email)
```
Если один сервис упал → нужен механизм rollback (Saga).

### 1.7. Когда использовать монолит

✅ **Используйте монолит, если:**

- Команда < 10 разработчиков
- Проект на ранней стадии (MVP, proof-of-concept)
- Требования меняются часто (проще рефакторить монолит)
- Нет высоких требований к масштабированию (< 100K users)
- Ограниченный бюджет на DevOps
- Простой бизнес-домен

**Примеры:** SaaS для малого бизнеса, internal tools, content сайты

### 1.8. Когда использовать микросервисы

✅ **Используйте микросервисы, если:**

- Большая команда (50+ разработчиков)
- Требуется независимое масштабирование компонентов
- Разные части системы имеют разные SLA (search 99.99%, admin 99%)
- Разные технологические требования (ML на Python, core на Java)
- Высокая нагрузка (millions RPS)
- Geo-distributed deployment

**Примеры:** E-commerce с миллионами пользователей, social networks, streaming platforms

### 1.9. Гибридный подход: Модульный монолит

**Модульный монолит** — компромисс между монолитом и микросервисами:

- Единый deployment unit
- Чёткое разделение на модули с интерфейсами
- Готовность к переходу на микросервисы

```
┌─────────────────────────────────┐
│    Modular Monolith             │
│  ┌───────┐  ┌──────┐  ┌──────┐  │
│  │User   │  │Doc   │  │Search│  │
│  │Module │→ │Module│→ │Module│  │
│  └───────┘  └──────┘  └──────┘  │
│       ↓         ↓         ↓      │
│     ┌──────────────────────┐    │
│     │   Shared Database    │    │
│     └──────────────────────┘    │
└─────────────────────────────────┘
```

**Преимущества:**
- Простота монолита + структура микросервисов
- Легко выделить модуль в микросервис при необходимости
- Хорошая отправная точка

**Примеры:** Shopify, GitHub начинали как модульные монолиты

### 1.10. Применение в ЛР4 (Поисковая система)

**Выбрана микросервисная архитектура:**

- **User Service**: аутентификация, профили (2 реплики)
- **Document Service**: CRUD документов (2 реплики)
- **Search Service**: полнотекстовый поиск (3 реплики для высокой нагрузки)
- **Indexer Workers**: асинхронная индексация (3 воркера)
- **Audit Service**: Event Sourcing (1 реплика)

**Обоснование:**
- Поиск требует больше ресурсов → 3 реплики Search vs 2 Document
- Индексация CPU-intensive → выделена в отдельные воркеры
- Fault isolation: падение indexer не влияет на поиск
- Каждый сервис имеет свою БД (users_db, documents_db, search_db, audit_db)

---

## 2. Горизонтальное масштабирование

### 2.1. Определения

**Вертикальное масштабирование (Scale Up)** — увеличение мощности одного сервера (CPU, RAM, SSD).

```
Before:              After:
┌─────────┐         ┌─────────┐
│ 4 CPU   │    →    │ 16 CPU  │
│ 8 GB    │         │ 64 GB   │
│ App     │         │ App     │
└─────────┘         └─────────┘
```

**Горизонтальное масштабирование (Scale Out)** — добавление большего количества серверов с распределением нагрузки.

```
Before:              After:
┌─────────┐         ┌─────────┐  ┌─────────┐  ┌─────────┐
│ 4 CPU   │    →    │ 4 CPU   │  │ 4 CPU   │  │ 4 CPU   │
│ 8 GB    │         │ 8 GB    │  │ 8 GB    │  │ 8 GB    │
│ App     │         │ App #1  │  │ App #2  │  │ App #3  │
└─────────┘         └─────────┘  └─────────┘  └─────────┘
                           ↑           ↑           ↑
                           └───────────┴───────────┘
                              Load Balancer
```

### 2.2. Сравнение

| Аспект | Вертикальное | Горизонтальное |
|--------|--------------|----------------|
| **Стоимость** | Экспоненциальный рост (сервер 64 CPU > 8x сервер 8 CPU) | Линейный рост |
| **Предел** | Физический лимит (1 TB RAM, 128 CPU) | Практически неограничен |
| **Downtime при масштабировании** | Требуется (reboot) | Нет (добавляем новые ноды) |
| **Отказоустойчивость** | SPOF (single point of failure) | Отказ одной ноды не критичен |
| **Сложность** | Простая (просто больше ресурсов) | Высокая (нужен балансировщик, синхронизация) |
| **Latency** | Низкая (всё на одной машине) | Выше (сетевые вызовы) |
| **Подходит для** | Databases, legacy apps | Stateless apps, веб-сервисы |

### 2.3. Пределы вертикального масштабирования

**Физические лимиты:**
- Максимальный сервер AWS: `u-24tb1.112xlarge`
  - 448 vCPU
  - 24 TB RAM
  - Стоимость: ~$218K/месяц

**Проблемы:**
1. **Diminishing returns**: удвоение ресурсов не удваивает производительность
2. **Amdahl's Law**: параллелизация ограничена sequential bottlenecks
3. **Single point of failure**: один сервер = один risk
4. **Vendor lock-in**: специальное железо трудно мигрировать

**Пример:** Database с 1 TB RAM может обслужить ~10K QPS, но 10 серверов по 100 GB могут обслужить 100K QPS (при правильном шардинге).

### 2.4. Преимущества горизонтального масштабирования

1. **Неограниченная масштабируемость**
   - Нужно больше мощности? Добавьте сервера
   - Netflix: 10K+ серверов
   - Google: миллионы серверов

2. **Fault tolerance**
   - 1 сервер из 100 упал → система теряет 1% capacity
   - Автоматический failover на здоровые ноды
   - Zero downtime deployment (rolling update)

3. **Cost-effective**
   - Используйте commodity hardware
   - Cloud: оплата по факту (Auto Scaling)
   - Лучше 10 серверов по $100/мес, чем 1 сервер за $2000/мес

4. **Geographic distribution**
   - Серверы в разных регионах (EU, US, Asia)
   - Низкая latency для пользователей
   - Compliance (GDPR требует хранить данные в EU)

**Пример:** Amazon распределяет запросы по датацентрам:
```
User in London → eu-west-1 (Ireland)
User in Tokyo  → ap-northeast-1 (Tokyo)
User in NYC    → us-east-1 (Virginia)
```

### 2.5. Вызовы горизонтального масштабирования

1. **State management**
   - Stateless services легко масштабируются
   - Stateful services (sessions, websockets) требуют sticky sessions или shared state

2. **Data consistency**
   - Нельзя использовать ACID транзакции между серверами
   - Eventual consistency
   - CAP-теорема

3. **Load balancing**
   - Нужен балансировщик (Nginx, HAProxy, AWS ALB)
   - Алгоритмы: Round Robin, Least Connections, IP Hash
   - Health checks для исключения упавших нод

4. **Deployment сложность**
   - Координация deployment на 100 серверах
   - Rolling update, Blue-Green, Canary
   - Service mesh (Istio, Linkerd)

5. **Network bottleneck**
   - Больше серверов = больше сетевого трафика
   - Нужна быстрая сеть (10 Gbps+)

**Пример проблемы:** Сессии пользователей хранятся в памяти сервера:
```
User logged in → Server 1 (session in memory)
Next request   → Server 2 (no session, user logged out!)
```

**Решение:** Shared session store (Redis, Memcached).

### 2.6. Когда использовать вертикальное масштабирование

✅ **Используйте вертикальное, если:**

- **Database with complex joins**
  - PostgreSQL с JOIN на 10 таблиц сложно шардировать
  - Лучше один мощный сервер с 256 GB RAM

- **Legacy монолит**
  - Невозможно/дорого рефакторить на микросервисы
  - Проще купить более мощный сервер

- **Cache сервер**
  - Redis с 100 GB dataset лучше на одном сервере
  - Network overhead убьёт производительность при распределении

- **Малая нагрузка**
  - < 10K users, зачем усложнять?

**Пример:** PostgreSQL Primary часто вертикально масштабируют до 96 CPU / 768 GB RAM перед тем как думать о шардинге.

### 2.7. Когда использовать горизонтальное масштабирование

✅ **Используйте горизонтальное, если:**

- **Stateless application**
  - API серверы (FastAPI, Express)
  - Static file servers (Nginx)

- **Высокая нагрузка**
  - Millions RPS
  - Unpredictable traffic (viral posts)

- **Требуется fault tolerance**
  - Сервис должен работать 99.99% времени
  - Один сервер = недопустимый риск

- **Microservices**
  - Каждый сервис масштабируется независимо

**Пример:** Web-серверы всегда горизонтально масштабируются (10, 100, 1000+ реплик).

### 2.8. Гибридный подход

**Best practice:** Используйте оба типа масштабирования:

1. **Application tier**: горизонтальное (stateless services)
2. **Database tier**: вертикальное (до предела) + репликация + шардинг

```
Load Balancer
     ↓
┌────────┬────────┬────────┐  ← Horizontal scaling
│App #1  │App #2  │App #3  │    (10-1000 nodes)
└────────┴────────┴────────┘
          ↓
  ┌───────────────┐
  │ PostgreSQL    │  ← Vertical scaling
  │ (64 CPU,      │    (1 powerful node)
  │  512 GB RAM)  │
  └───────────────┘
```

### 2.9. Применение в ЛР4 (Поисковая система)

**Горизонтальное масштабирование:**

- **Search Service**: 3 реплики (high load)
  ```yaml
  search-service:
    deploy:
      replicas: 3
  ```

- **Indexer Workers**: 3 воркера (parallel processing)
- **User Service**: 2 реплики (redundancy)
- **Document Service**: 2 реплики (redundancy)

**Вертикальное масштабирование:**

- **PostgreSQL Primary**:
  ```yaml
  resources:
    limits:
      cpus: '4'
      memory: 4G
  ```

**Балансировка нагрузки:**

```nginx
upstream search_backend {
    least_conn;  # Алгоритм балансировки
    server search-service-1:8000;
    server search-service-2:8000;
    server search-service-3:8000;
}
```

**Автомасштабирование (для production):**

```yaml
# Kubernetes HPA
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: search-service
spec:
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

---

## 3. Трёхзвенная архитектура

### 3.1. Определение

**Трёхзвенная архитектура (Three-Tier Architecture)** — паттерн разделения приложения на три логических и физических уровня:

1. **Presentation Tier** (Уровень представления)
2. **Application Tier** (Уровень приложения/бизнес-логики)
3. **Data Tier** (Уровень данных)

```
┌────────────────────────────┐
│   Presentation Tier        │  ← User Interface
│   (Frontend)               │    HTML, CSS, JS
└────────────────────────────┘
            ↕ HTTP/REST
┌────────────────────────────┐
│   Application Tier         │  ← Business Logic
│   (Backend API)            │    Microservices
└────────────────────────────┘
            ↕ SQL/Protocol
┌────────────────────────────┐
│   Data Tier                │  ← Data Storage
│   (Database, Cache)        │    PostgreSQL, Redis
└────────────────────────────┘
```

### 3.2. Presentation Tier (Уровень представления)

**Роль:**
- Отображение данных пользователю
- Обработка пользовательского ввода
- UX/UI logic
- Минимальная бизнес-логика (валидация форм)

**Технологии:**
- **Web**: HTML, CSS, JavaScript (React, Vue, Angular)
- **Mobile**: Swift (iOS), Kotlin (Android), React Native
- **Desktop**: Electron, Qt, WPF

**Что НЕ должно быть:**
- ❌ Прямые запросы к базе данных
- ❌ Сложная бизнес-логика
- ❌ Секреты (API keys, credentials)

**Пример (ЛР4):**
```javascript
// frontend/app.js
async function performSearch() {
    const query = document.getElementById('search-input').value;
    
    // Только HTTP-запрос к API, никакой бизнес-логики
    const response = await fetch(`/api/search?q=${query}`);
    const results = await response.json();
    
    displayResults(results);
}
```

### 3.3. Application Tier (Уровень приложения)

**Роль:**
- Бизнес-логика приложения
- Обработка запросов от Presentation
- Валидация данных
- Интеграция с внешними системами
- Авторизация и аутентификация

**Технологии:**
- **Backend frameworks**: FastAPI (Python), Express (Node.js), Spring Boot (Java)
- **API protocols**: REST, GraphQL, gRPC
- **Message queues**: RabbitMQ, Kafka

**Что должно быть:**
- ✅ Все бизнес-правила (pricing, discounts, scoring)
- ✅ Data validation (email format, password strength)
- ✅ Orchestration между сервисами
- ✅ Caching logic

**Пример (ЛР4):**
```python
# search-service/main.py
@app.get("/api/search")
async def search(q: str, limit: int = 10):
    # 1. Валидация
    if not q or len(q) < 2:
        raise HTTPException(400, "Query too short")
    
    # 2. Кэш
    cache_key = f"search:{hash(q)}"
    cached = await redis.get(cache_key)
    if cached:
        return json.loads(cached)
    
    # 3. Бизнес-логика: поиск в БД
    results = await db.fetch("""
        SELECT d.id, d.title, d.content
        FROM terms t
        JOIN postings p ON t.id = p.term_id
        JOIN documents d ON p.doc_id = d.id
        WHERE t.term = $1
        ORDER BY p.tf_idf DESC
        LIMIT $2
    """, q, limit)
    
    # 4. Кэширование результата
    await redis.setex(cache_key, 300, json.dumps(results))
    
    return {"results": results, "cache_hit": False}
```

### 3.4. Data Tier (Уровень данных)

**Роль:**
- Хранение данных (persistent storage)
- Обеспечение ACID-свойств (для SQL)
- Индексация для быстрого поиска
- Репликация для отказоустойчивости
- Backup и восстановление

**Технологии:**
- **RDBMS**: PostgreSQL, MySQL, Oracle
- **NoSQL**: MongoDB, Cassandra, DynamoDB
- **Cache**: Redis, Memcached
- **Search engines**: Elasticsearch, Meilisearch
- **Object storage**: MinIO, S3

**Что должно быть:**
- ✅ Схемы данных (tables, indexes)
- ✅ Stored procedures (опционально, для сложной логики)
- ✅ Triggers для автоматизации
- ✅ Constraints (foreign keys, unique)

**Пример (ЛР4):**
```sql
-- database/init-scripts/01-init-databases.sql

-- База для поиска
CREATE TABLE terms (
    id BIGSERIAL PRIMARY KEY,
    term VARCHAR(255) UNIQUE NOT NULL,
    doc_count INTEGER DEFAULT 0
);

CREATE TABLE postings (
    id BIGSERIAL PRIMARY KEY,
    term_id BIGINT REFERENCES terms(id),
    doc_id UUID NOT NULL,
    position INTEGER,
    tf_idf FLOAT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Индекс для быстрого поиска
CREATE INDEX idx_postings_term_id ON postings(term_id);
CREATE INDEX idx_postings_doc_id ON postings(doc_id);
```

### 3.5. Преимущества трёхзвенной архитектуры

1. **Separation of Concerns**
   - Frontend разработчики работают независимо от backend
   - DBA управляют БД без знания бизнес-логики
   - Модульность

2. **Масштабируемость**
   - Каждый tier масштабируется независимо
   - Frontend → CDN
   - Application → horizontal scaling
   - Data → replication + sharding

3. **Безопасность**
   - Frontend не имеет прямого доступа к БД
   - Application tier проверяет авторизацию
   - Data tier за firewall (private network)

4. **Flexibility**
   - Можно заменить Frontend (web → mobile app) без изменения backend
   - Можно мигрировать БД (MySQL → PostgreSQL) без изменения API
   - Testability: можно тестировать каждый tier отдельно

**Пример:** Spotify:
- **Presentation**: Web app, iOS app, Android app, Desktop app
- **Application**: API Gateway, Music Service, Playlist Service, Recommendation Service
- **Data**: User DB, Track DB, Analytics DB, Cache

Все 4 frontend используют один Application tier.

### 3.6. Недостатки трёхзвенной архитектуры

1. **Network latency**
   - Каждый tier = network hop
   - Frontend → API: 50ms
   - API → Database: 5ms
   - Total: 55ms (vs 1ms для monolith)

2. **Сложность deployment**
   - 3 независимых компонента
   - Версионирование API (breaking changes)
   - Координация deployment

3. **Overhead**
   - Сериализация/десериализация (JSON, Protocol Buffers)
   - Authentication на каждом уровне

4. **Single point of failure**
   - Application tier падает → весь сервис недоступен
   - Database падает → всё ломается

**Митигация:**
- Репликация (multiple instances per tier)
- Load balancing
- Circuit breakers

### 3.7. Альтернативы

**Two-Tier (Client-Server):**
```
┌──────────┐
│  Client  │ ← Business logic здесь!
└──────────┘
      ↕
┌──────────┐
│ Database │
└──────────┘
```

**Проблемы:**
- Бизнес-логика размазана между клиентом и БД
- Сложно поддерживать (обновить логику = обновить все клиенты)
- Security issues (клиент знает структуру БД)

**N-Tier (> 3 уровня):**
```
Frontend → API Gateway → Microservices → Message Queue → Database
```

Используется в сложных enterprise-системах (банки, e-commerce).

### 3.8. Применение в ЛР4

**Presentation Tier:**
- **Nginx** (static files): HTML, CSS, JavaScript
- **Frontend**: Single Page Application (SPA)
- Порт: 80

**Application Tier:**
- **User Service** (2 реплики)
- **Document Service** (2 реплики)
- **Search Service** (3 реплики)
- **Indexer Workers** (3 воркера)
- **Audit Service** (1 реплика)
- Протокол: REST API (JSON)

**Data Tier:**
- **PostgreSQL Primary + Standby** (репликация)
- **ValKey (Redis)** (кэш)
- **RabbitMQ** (message queue)
- Сети: private (backend network)

**Схема:**
```
[User Browser]
      ↓ HTTP
[Nginx :80] ← Presentation Tier
      ↓ HTTP/JSON
[Microservices] ← Application Tier
      ↓ SQL/Redis/AMQP
[PostgreSQL, ValKey, RabbitMQ] ← Data Tier
```

**Физическое разделение:**
- Frontend network: доступен извне
- Backend network: изолирован (only Nginx can access)

---

## 4. Обработка запросов фронтендом и бэкендом

### 4.1. Разделение ответственности

**Frontend обрабатывает:**
- Валидация форм на клиенте
- Рендеринг UI компонентов
- Роутинг (SPA)
- Кэширование статических ресурсов
- Оптимизация загрузки (lazy loading, code splitting)

**Backend обрабатывает:**
- Бизнес-логика
- Авторизация и аутентификация
- Работа с базой данных
- Интеграция с внешними сервисами
- Валидация данных (критически важная)

### 4.2. Для поисковой системы

```
User Request: "python tutorial"
    │
    ▼
[Frontend: HTML/JS]
    │ autocomplete, highlighting
    ▼
[Nginx Gateway]
    │ балансировка, кэш
    ▼
[Search Service API]
    │ парсинг запроса, ранжирование
    ▼
[PostgreSQL Search DB]
    │ full-text search
    ▼
Return: [Results JSON]
```

---

## 5. Кэширование и отдача статики

### 5.1. Уровни кэширования

**1. Browser Cache (Client-side)**
```
Cache-Control: public, max-age=31536000
```
- Статика: CSS, JS, images
- Срок: до 1 года

**2. CDN Cache**
```
CloudFlare / Akamai
```
- Geographic distribution
- Edge locations

**3. Reverse Proxy Cache (Nginx)**
```nginx
proxy_cache_path /var/cache/nginx keys_zone=api_cache:10m;
proxy_cache_valid 200 5m;
```

**4. Application Cache (ValKey/Redis)**
```python
valkey.set("search:results:python", json_data, ex=300)
```

### 5.2. Стратегии инвалидации

- **TTL (Time To Live)**: Автоматическое истечение
- **Event-driven**: При изменении данных
- **Cache-aside**: Проверка актуальности

### 5.3. Для поисковой системы

```
Static Assets (CSS/JS/Images)
    ↓ CDN (1 year)
Search Results
    ↓ ValKey (5 min)
Document Metadata
    ↓ Nginx (1 min)
User Sessions
    ↓ ValKey (30 min)
```

---

## 6. Вычисления на стороне клиента

### 6.1. Преимущества

**Снижение нагрузки на сервер:**
- Валидация форм
- Сортировка/фильтрация результатов
- Подсветка синтаксиса
- Анимации и переходы

**Улучшение UX:**
- Мгновенный отклик
- Offline capabilities (Service Workers)
- Интерактивность

### 6.2. Для поисковой системы

**Client-side обработка:**
```javascript
// Подсветка ключевых слов в результатах
function highlightKeywords(text, query) {
    const regex = new RegExp(query, 'gi');
    return text.replace(regex, '<mark>$&</mark>');
}

// Autocomplete (debounced)
debounce(fetchSuggestions, 300);

// Client-side сортировка результатов
results.sort((a, b) => b.relevance - a.relevance);
```

### 6.3. Ограничения

- Защита данных (не хранить секреты)
- Производительность (мобильные устройства)
- Доступность (JavaScript отключён)

---

## 7. Масштабирование фронтенда и бэкенда

### 7.1. Horizontal Scaling (Масштабирование)

**Frontend:**
```
        ┌──────────────┐
Users ──│ CDN / Nginx  │── Static Files (3 replicas)
        └──────────────┘
```

**Backend:**
```
Nginx ──┬──► User Service (3 pods)
        ├──► Document Service (5 pods)
        ├──► Search Service (7 pods)
        └──► Audit Service (2 pods)
```

### 7.2. Load Balancing алгоритмы

**Round Robin:**
```
Request 1 → Server 1
Request 2 → Server 2
Request 3 → Server 3
Request 4 → Server 1 (cycle)
```

**Least Connections:**
```
Choose server with fewest active connections
```

**IP Hash:**
```
hash(client_ip) % server_count = server_id
```

### 7.3. Для поисковой системы

**Приоритеты:**
- Search Service: 7 replicas (highest load)
- Document Service: 5 replicas (indexing)
- User Service: 3 replicas (authentication)
- Audit Service: 2 replicas (background)

**Auto-scaling:**
```yaml
autoscaling:
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

---

## 8. DNS-балансировка (Round Robin DNS)

### 8.1. Принцип работы

**Простая схема:**
```
search.example.com
    ├─► 192.168.1.10 (Server 1)
    ├─► 192.168.1.11 (Server 2)
    └─► 192.168.1.12 (Server 3)
```

**DNS Response:**
```
nslookup search.example.com
> 192.168.1.10
> 192.168.1.11
> 192.168.1.12
```

### 8.2. Geographic DNS (GeoDNS)

```
User в России   → ru.search.example.com (Moscow DC)
User в США      → us.search.example.com (NYC DC)
User в Европе   → eu.search.example.com (Frankfurt DC)
```

### 8.3. Недостатки Round Robin DNS

- Нет health checks
- DNS caching (TTL проблемы)
- Неравномерное распределение
- Не учитывает load

**Решение**: Использовать L4/L7 балансировщики (Nginx, HAProxy) + DNS

---

## 9. Отказоустойчивость

### 9.1. Методы обеспечения

**1. Redundancy (Избыточность)**
- Multiple instances
- Database replication
- Geographic distribution

**2. Failover**
```
Primary node fails
    ↓
Monitor detects (pg_auto_failover)
    ↓
Promote Secondary to Primary
    ↓
Update DNS / Load Balancer
```

**3. Health Checks**
```python
@app.get("/health")
async def health_check():
    db_ok = await check_database()
    cache_ok = await check_redis()
    return {"status": "healthy" if all([db_ok, cache_ok]) else "degraded"}
```

**4. Circuit Breaker**
```python
if error_rate > threshold:
    open_circuit()  # Stop sending requests
    return cached_response or fallback
```

### 9.2. Для поисковой системы

**Реализовано:**
- PostgreSQL: pg_auto_failover (3 nodes)
- Backup/Restore: ежечасно, 7-day retention
- Canary Deployment: 90/10 split
- Event Sourcing: восстановление из audit log

**Результаты тестов:**
- Failover time: ~30 seconds
- Data loss: 0 (streaming replication)
- RTO (Recovery Time Objective): < 1 minute
- RPO (Recovery Point Objective): < 10 seconds

---

## 10. Масштабирование баз данных

### 10.1. Методы масштабирования

**1. Репликация (Replication)**
```
    ┌──────────┐
    │ Primary  │─────────┐
    └──────────┘         │
          │              │ (WAL streaming)
    (write)              ▼
          │        ┌──────────┐
          │        │Secondary │
          │        └──────────┘
          │              │ (read)
```

**2. Шардинг (Sharding)**
```
Users A-M  → Shard 1
Users N-Z  → Shard 2
```

**3. Партиционирование (Partitioning)**
```sql
-- Range partitioning by date
CREATE TABLE events_2025_10 PARTITION OF events
FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
```

**4. Кластеризация**
- Patroni + etcd
- Galera Cluster
- Citus (distributed PostgreSQL)

### 10.2. Для поисковой системы

**Применено:**
1. **Streaming Replication**: Master (write) + Standby (read)
2. **Partitioning**: audit_db по месяцам
3. **Indexes**: GIN для full-text search
4. **Connection Pooling**: asyncpg (2-10 connections)

**Оптимизации:**
```sql
-- Full-text search index
CREATE INDEX idx_documents_content 
ON documents USING GIN (to_tsvector('english', content));

-- Inverted index для поиска
CREATE TABLE postings (
    term_id INT,
    document_id INT,
    position INT[],
    PRIMARY KEY (term_id, document_id)
);
```

---

## 11. Надёжность и резервирование

### 11.1. Принципы надёжности

**SLA (Service Level Agreement):**
```
99.9%  = 8.76 hours downtime/year
99.95% = 4.38 hours downtime/year
99.99% = 52.56 minutes downtime/year
```

**Формула доступности:**
```
Availability = MTBF / (MTBF + MTTR)
MTBF = Mean Time Between Failures
MTTR = Mean Time To Repair
```

### 11.2. Стратегии резервирования

**1. Active-Passive**
```
Primary (active) ──► Standby (passive)
    │ heartbeat
    ▼
If Primary fails → Standby becomes Primary
```

**2. Active-Active**
```
Node 1 (active) ─┬─► Load Balancer
Node 2 (active) ─┘
```

**3. Backup Strategies**

**3-2-1 Rule:**
- 3 copies of data
- 2 different storage types
- 1 offsite backup

### 11.3. Для поисковой системы

**Implemented:**
1. **Database**: 3 nodes (1 Primary, 2 Standby)
2. **Backups**: pg_dump every hour, 7-day retention
3. **Monitoring**: Prometheus + Grafana
4. **Audit Log**: Event Sourcing для восстановления
5. **Canary Deployment**: Постепенный rollout

**Disaster Recovery Plan:**
```
Scenario 1: Primary DB fails
    → pg_auto_failover promotes Standby (~30s)
    
Scenario 2: Data corruption
    → Restore from backup (< 5 min)
    → Replay events from audit log
    
Scenario 3: Entire datacenter down
    → Failover to backup region (manual)
```

---

## 12. CAP-теорема

### 12.1. Определение

**CAP = Consistency, Availability, Partition Tolerance**

Невозможно одновременно гарантировать все три свойства:
- **C (Consistency)**: Все читают одинаковые данные
- **A (Availability)**: Система всегда отвечает
- **P (Partition Tolerance)**: Работа при разделении сети

### 12.2. Компромиссы

**CA (Consistency + Availability):**
- PostgreSQL (single-node)
- MySQL (без репликации)
- ❌ Не работает при network partition

**CP (Consistency + Partition Tolerance):**
- MongoDB (strong consistency)
- HBase, BigTable
- ❌ Недоступно при разделении

**AP (Availability + Partition Tolerance):**
- Cassandra, DynamoDB
- ValKey/Redis (with replication)
- ❌ Eventually consistent (задержка)

### 12.3. Для поисковой системы (Вариант 8)

**Выбор: CP (Consistency + Partition Tolerance)**

**Обоснование:**
1. **Consistency важнее**: Результаты поиска должны быть точными
2. **Partition Tolerance**: pg_auto_failover обеспечивает работу при сбоях
3. **Availability**: Допустима кратковременная недоступность (~30s failover)

**Реализация:**
```
PostgreSQL с синхронной репликацией:
    Primary ────(sync)───► Standby
        │
        ├─ Commit подтверждён только если 
        │  записано на Standby
        │
        └─ При network partition: 
           Primary становится read-only
```

**Trade-offs:**
- ✅ Гарантия актуальных данных
- ✅ Нет lost updates
- ⚠️ Задержка записи (+10-50ms)
- ⚠️ Possible downtime при failover

**Альтернатива (AP):**
Если бы требовалась максимальная доступность:
```
Cassandra + Eventual Consistency
    → Быстрое чтение/запись
    → Могут быть устаревшие результаты поиска
```

---

## Заключение

Все 12 тем теоретической части рассмотрены применительно к **Варианту 8 (Поисковая система)**. Архитектура спроектирована с учётом:
- Микросервисов (User, Document, Search, Audit)
- Горизонтального масштабирования (Nginx + multiple replicas)
- Отказоустойчивости (pg_auto_failover, backups, canary)
- CAP компромиссов (CP-модель для точности поиска)

**Итоговая архитектура обеспечивает:**
- Availability: 99.9% (с учётом failover)
- Consistency: Строгая (синхронная репликация)
- Scalability: Горизонтальная (до 10x instances)
- Durability: Backup + Event Sourcing
