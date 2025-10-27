# 🗄️ Подключение к PostgreSQL с Windows

## 📊 Доступные базы данных

### 1️⃣ NODE1 (PRIMARY) - Основная БД для чтения и записи

```
Host:     localhost
Port:     5432
Database: app_db
Username: docker
Password: secret
```

**Connection String:**
```
postgresql://docker:secret@localhost:5432/app_db
```

**Таблицы:**
- `documents` - документы для поиска
- `users` - пользователи
- `search_documents` - индексированные документы для FTS
- `terms` - словарь терминов для поиска
- `postings` - инвертированный индекс

---

### 2️⃣ NODE2 (SECONDARY) - Реплика только для чтения

```
Host:     localhost
Port:     5433
Database: app_db
Username: docker
Password: secret
```

**Connection String:**
```
postgresql://docker:secret@localhost:5433/app_db
```

**⚠️ READ-ONLY:** Эта нода автоматически реплицирует данные с NODE1.
Используется для:
- Распределения нагрузки на чтение
- Отказоустойчивости (при падении NODE1, NODE2 станет PRIMARY)

---

### 3️⃣ MONITOR - Мониторинг кластера pg_auto_failover

```
Host:     localhost
Port:     5434
Database: pg_auto_failover
Username: autoctl_node
Password: secret
```

**Connection String:**
```
postgresql://autoctl_node:secret@localhost:5434/pg_auto_failover
```

**Таблицы:**
- `pgautofailover.node` - информация о нодах кластера
- `pgautofailover.formation` - конфигурация формаций
- `pgautofailover.event` - события failover

---

## 🔧 Подключение через клиенты

### DBeaver

1. **Создать новое подключение:**
   - Database → New Database Connection
   - Выбрать PostgreSQL
   
2. **Настройки NODE1:**
   ```
   Host: localhost
   Port: 5432
   Database: app_db
   Username: docker
   Password: secret
   ```

3. **Test Connection** → Finish

4. Повторить для NODE2 (порт 5433) и MONITOR (порт 5434)

---

### pgAdmin

1. **Add New Server:**
   - General → Name: `NODE1 - Primary`
   
2. **Connection:**
   ```
   Host: localhost
   Port: 5432
   Maintenance database: app_db
   Username: docker
   Password: secret
   ```
   
3. **Save** → Connect

---

### psql (командная строка)

```powershell
# NODE1 (PRIMARY)
docker exec -it pgauto-node1 psql -U docker -d app_db

# NODE2 (SECONDARY)
docker exec -it pgauto-node2 psql -U docker -d app_db

# MONITOR
docker exec -it pgauto-monitor psql -U autoctl_node -d pg_auto_failover
```

**Или напрямую с Windows** (если установлен PostgreSQL client):
```powershell
# NODE1
psql -h localhost -p 5432 -U docker -d app_db

# NODE2
psql -h localhost -p 5433 -U docker -d app_db

# MONITOR
psql -h localhost -p 5434 -U autoctl_node -d pg_auto_failover
```

---

## 📊 Полезные SQL запросы

### Проверка документов (NODE1 или NODE2)

```sql
-- Всего документов
SELECT COUNT(*) FROM documents;

-- Последние 10 документов
SELECT id, title, author, indexed, created_at 
FROM documents 
ORDER BY created_at DESC 
LIMIT 10;

-- Статистика по индексации
SELECT 
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE indexed = true) as indexed,
    COUNT(*) FILTER (WHERE indexed = false) as pending,
    ROUND(100.0 * COUNT(*) FILTER (WHERE indexed = true) / COUNT(*), 2) as percent_indexed
FROM documents;

-- Поиск документов
SELECT id, title, author 
FROM documents 
WHERE title ILIKE '%PostgreSQL%' 
ORDER BY created_at DESC;
```

### Проверка пользователей (NODE1 или NODE2)

```sql
-- Всего пользователей
SELECT COUNT(*) FROM users;

-- Список пользователей
SELECT id, username, email, created_at 
FROM users 
ORDER BY created_at DESC;
```

### Проверка состояния кластера (MONITOR)

```sql
-- Статус нод кластера
SELECT 
    nodeid,
    nodehost,
    nodeport,
    health,
    state,
    goalstate
FROM pgautofailover.node
ORDER BY nodeid;

-- История событий failover
SELECT 
    eventid,
    eventtime,
    formationid,
    nodeid,
    reportedstate,
    goalstate,
    description
FROM pgautofailover.event
ORDER BY eventtime DESC
LIMIT 20;

-- Информация о формациях
SELECT * FROM pgautofailover.formation;
```

### Проверка репликации (NODE1)

```sql
-- Статус репликации
SELECT 
    client_addr,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    sync_state
FROM pg_stat_replication;

-- Задержка репликации
SELECT 
    client_addr,
    state,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replication_lag_bytes
FROM pg_stat_replication;
```

---

## 🧪 Проверка наполнения всех БД

**Автоматическая проверка:**
```powershell
.\scripts\check-databases.ps1
```

**Ручная проверка:**

### 1. Проверить NODE1
```powershell
docker exec -it pgauto-node1 psql -U docker -d app_db -c "\dt"
docker exec -it pgauto-node1 psql -U docker -d app_db -c "SELECT COUNT(*) FROM documents;"
docker exec -it pgauto-node1 psql -U docker -d app_db -c "SELECT COUNT(*) FROM users;"
```

### 2. Проверить NODE2 (должно совпадать с NODE1)
```powershell
docker exec -it pgauto-node2 psql -U docker -d app_db -c "SELECT COUNT(*) FROM documents;"
docker exec -it pgauto-node2 psql -U docker -d app_db -c "SELECT COUNT(*) FROM users;"
```

### 3. Проверить MONITOR
```powershell
docker exec -it pgauto-monitor psql -U autoctl_node -d pg_auto_failover -c "\dt pgautofailover.*"
docker exec -it pgauto-monitor psql -U autoctl_node -d pg_auto_failover -c "SELECT * FROM pgautofailover.node;"
```

---

## 🎯 Быстрая диагностика

```powershell
# Проверка состояния кластера
docker exec pgauto-node1 pg_autoctl show state

# Должно быть:
# node_1: primary (read-write)
# node_2: secondary (read-only)

# Проверка подключения к NODE1
docker exec pgauto-node1 psql -U docker -d app_db -c "SELECT version();"

# Проверка подключения к NODE2
docker exec pgauto-node2 psql -U docker -d app_db -c "SELECT version();"

# Проверка подключения к MONITOR
docker exec pgauto-monitor psql -U autoctl_node -d pg_auto_failover -c "SELECT version();"
```

---

## 📝 Примечания

1. **NODE1** - всегда используйте для записи данных (INSERT, UPDATE, DELETE)
2. **NODE2** - используйте для чтения (SELECT) для распределения нагрузки
3. **MONITOR** - служебная БД, не используется приложениями напрямую
4. Все пароли: `secret` (для тестирования, в продакшн используйте надежные пароли!)
5. При падении NODE1, NODE2 автоматически становится PRIMARY

---

✅ **Готово к подключению из любого клиента!**
