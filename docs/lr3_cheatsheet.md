# ЛР3 — PostgreSQL: репликация, авто‑failover и денормализация (пошаговая шпаргалка)

Цель: развернуть кластер PostgreSQL из трёх контейнеров, настроить репликацию Master‑Replica, автоматическое переключение (pg_auto_failover), выполнить Вариант 3 (денормализация для отчётов) и защитить работу из терминала (или в UI pgAdmin/Chrome).

## Архитектура

- Кластер auto‑failover (`pg_auto/`):
   - monitor (5434) — координация, хранит состояния узлов.
   - node1 (5432) — узел данных (primary/replica).
   - node2 (5433) — узел данных (primary/replica).
   - Между node1 и node2 — streaming‑репликация; ролями управляет monitor (pg_autoctl).

- Вариант 3: `lr3/variant3_schema.sql` — `products`, `orders`, `sales_report` + функции/триггеры.
- Вариант вычисления: `get_variant.py` — печатает номер варианта (var_total=5) → 3.

Примечание: старый стек `pg_cluster/` удалён. Используем только `pg_auto` + `lr3/variant3_schema.sql`.

## Пошаговый сценарий для защиты (PowerShell)

```pwsh
# 0) Показать свой вариант
python .\get_variant.py

# 1) Поднять кластер (идемпотентно)
docker compose -f pg_auto/docker-compose.yml up -d

# 2) Убедиться, что сервисы поднялись
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | findstr pgauto

# 3) Определить роли и установить переменные $PRIMARY и $REPLICA
$n1 = (docker exec -i pgauto-node1 psql -U docker -d app_db -t -A -c "select pg_is_in_recovery();").Trim()
if ($n1 -eq 'f') { $PRIMARY='pgauto-node1'; $REPLICA='pgauto-node2' } else { $PRIMARY='pgauto-node2'; $REPLICA='pgauto-node1' }
Write-Host "PRIMARY=$PRIMARY  REPLICA=$REPLICA"

# 4) Проверка репликации: создать таблицу и запись на PRIMARY
docker exec -i $PRIMARY psql -U docker -d app_db -c "CREATE TABLE IF NOT EXISTS test (id SERIAL PRIMARY KEY, data VARCHAR); INSERT INTO test (data) VALUES ('replication_test') ON CONFLICT DO NOTHING;"

# 5) Прочитать на REPLICA (запись должна быть видна)
docker exec -i $REPLICA psql -U docker -d app_db -c "SELECT * FROM test ORDER BY id;"

# 6) Применить Вариант 3 (схема и триггеры) на PRIMARY
type "lr3\variant3_schema.sql" | docker exec -i $PRIMARY psql -U docker -d app_db

# 7) Наполнить данными и проверить отчёт на обоих узлах
# В PowerShell используйте один -c с командами через ; на одной строке
docker exec -i $PRIMARY psql -U docker -d app_db -c "INSERT INTO products(id,name,price) VALUES (1,'Phone',100.0),(2,'Laptop',1500.0) ON CONFLICT (id) DO NOTHING; INSERT INTO orders(id,product_id,quantity) VALUES (1,1,2),(2,2,1) ON CONFLICT (id) DO NOTHING; SELECT * FROM sales_report ORDER BY product_id;"
docker exec -i $REPLICA psql -U docker -d app_db -c "SELECT * FROM sales_report ORDER BY product_id;"

# 8) Проверка UPDATE‑триггера (инкремент): Phone qty станет 3
docker exec -i $PRIMARY psql -U docker -d app_db -c "UPDATE orders SET quantity = quantity + 1 WHERE id = 1; SELECT * FROM sales_report ORDER BY product_id;"

# 9) Авто‑failover: остановить текущий PRIMARY (запомним, кого остановили)
$STOPPED = $PRIMARY
docker stop $STOPPED
Start-Sleep -Seconds 12

# 10) Определить новый PRIMARY/REPLICA надёжно (живым остался второй узел)
if ($STOPPED -eq 'pgauto-node1') { $PRIMARY='pgauto-node2'; $REPLICA='pgauto-node1' } else { $PRIMARY='pgauto-node1'; $REPLICA='pgauto-node2' }
Write-Host "After failover (expected): PRIMARY=$PRIMARY  REPLICA=$REPLICA"
# Проверка, что новый PRIMARY действительно в режиме primary
docker exec -i $PRIMARY psql -U docker -d app_db -c "SELECT 'is_primary' as check, NOT pg_is_in_recovery() AS ok;"

# 11) Запись на новом PRIMARY проходит
docker exec -i $PRIMARY psql -U docker -d app_db -c "INSERT INTO test(data) VALUES ('after_failover'); SELECT * FROM test ORDER BY id;"

# 12) Вернуть упавший узел и убедиться, что он стал REPLICA
docker start $REPLICA
Start-Sleep -Seconds 10
docker exec -i $REPLICA psql -U docker -d app_db -c "SELECT 'replica' as role, pg_is_in_recovery(); SELECT COUNT(*) FROM test;"

# 13) Попытка записи на реплике должна дать read‑only ошибку
docker exec -i $REPLICA psql -U docker -d app_db -c "INSERT INTO test(data) VALUES ('should_fail');"
```

Ожидания:
- Шаг 5: на REPLICA видна строка replication_test.
- Шаг 7–8: в sales_report: Phone qty=2→3, revenue 200→300; Laptop qty=1, revenue=1500 на обоих узлах.
- Шаг 10: роли поменялись — новый PRIMARY имеет `pg_is_in_recovery=false`.
- Шаг 13: ошибка `cannot execute INSERT in a read-only transaction`.

Опционально (UI): подключитесь pgAdmin/DBeaver к 5432 и 5433 (Chrome для pgAdmin) и покажите роли/данные.

## Управление и полезные команды

```pwsh
# Запуск/остановка всего кластера
docker compose -f pg_auto/docker-compose.yml up -d
docker compose -f pg_auto/docker-compose.yml down

# Логи
docker logs -f --tail=100 pgauto-monitor
docker logs -f --tail=100 pgauto-node1
docker logs -f --tail=100 pgauto-node2

# Прямой psql
docker exec -it pgauto-node1 psql -U docker -d app_db
docker exec -it pgauto-node2 psql -U docker -d app_db
```

## Как это работает (коротко)

- Образ `citusdata/pg_auto_failover` включает PostgreSQL и `pg_autoctl`.
- monitor хранит состояние кластера; узлы регистрируются через `pg_autoctl create postgres`.
- Реплика создаётся `pg_basebackup`, дальше подтягивает WAL.
- При сбое monitor продвигает standby в primary; вернувшийся узел становится replica.
- Денормализация: триггеры на `orders`/`products` поддерживают агрегат `sales_report`, ускоряя отчёты.

## Чек‑лист соответствия

- [x] 3 контейнера на 5432/5433/5434.
- [x] Репликация Master‑Replica работает.
- [x] Автоматический failover (pg_autoctl) продемонстрирован.
- [x] Вариант 3: таблицы, функции, триггеры, корректный `sales_report`.
- [x] Команды и сценарий защиты готовы.

## Ответы на контрольные вопросы

1) Синхронная vs асинхронная: синхронная — коммит после записи на реплику (лучше RPO, выше задержки); асинхронная — быстрее, но возможна потеря последних транзакций.
2) Индексы для диапазонов: B‑Tree (числа/даты), GiST (сложные типы/гео), BRIN (очень большие упорядоченные таблицы).
3) Риски денормализации: дублирование и необходимость поддерживать согласованность (триггеры/процедуры); ошибки дают рассинхронизацию.
4) Партиционирование: уменьшает объём сканирования (partition pruning), ускоряет DML/обслуживание; важен правильный ключ.
5) Критичные параметры OLTP: `shared_buffers`, `effective_cache_size`, `work_mem`, `maintenance_work_mem`, `max_connections`, `checkpoint_timeout`, `max_wal_size`, `wal_compression`, `synchronous_commit`, `autovacuum`.

## Глоссарий терминов

- DML (Data Manipulation Language) — язык манипулирования данными: INSERT, UPDATE, DELETE, а также UPSERT (INSERT ... ON CONFLICT); меняет содержимое таблиц.
- HA (High Availability) — высокая доступность: архитектурные и операционные практики, обеспечивающие минимальные RPO/RTO и продолжение работы при сбоях (например, через репликацию и автоматический failover).
- LSN (Log Sequence Number) — позиция в WAL, уникально идентифицирующая запись журнала; используется для измерения lag репликации, точек восстановления и согласования состояния узлов.
- RPO (Recovery Point Objective) — допустимая потеря данных при сбое, измеряется временем «сколько последних секунд/минут можно потерять». В асинхронной репликации RPO > 0, в синхронной стремится к 0.
- RTO (Recovery Time Objective) — допустимое время восстановления сервиса до работоспособности после сбоя.
- Primary (master) — ведущий узел, принимает запись и формирует WAL.
- Replica (standby) — ведомый узел, как правило read‑only; применяет WAL с primary.
- Failover — аварийное автоматическое переключение ролей replica → primary при недоступности текущего primary.
- Switchover — плановая смена ролей между узлами без аварии.
- Streaming replication — потоковая передача WAL на реплики в реальном времени.
- WAL (Write‑Ahead Log) — журнал предзаписи; основа репликации и восстановления.
- Checkpoint — фиксация состояния буфера на диск; влияет на время восстановления и I/O‑нагрузку.
- Replication lag — отставание реплики от primary (по времени/LSN); напрямую влияет на фактический RPO.
- Hot standby — режим реплики, позволяющий выполнять SELECT (но не DML) на standby.
- Synchronous commit — подтверждение транзакции только после доставки (и/или записи) WAL на реплику(и).
- pg_auto_failover — инструмент (monitor + pg_autoctl) для управления кластером PostgreSQL с автоматическим failover.
- Monitor — координирующий узел pg_auto_failover, хранит состояние кластера и принимает решения о переключении ролей.
- pg_autoctl — утилита управления, регистрирует узлы и запускает процессы PostgreSQL/репликации.
- Денормализация — осознанное дублирование/агрегация данных ради ускорения чтения; требует механизмов консистентности (триггеры/процедуры/ETL).
- Материализованное представление — сохранённый результат запроса; быстрое чтение, но нужен периодический REFRESH для актуальности.
- Триггер — процедура, выполняемая при событиях DML/DDL; в варианте 3 поддерживает агрегат `sales_report`.
- Партиционирование — разбиение таблицы на секции; ускоряет сканирование (partition pruning) и обслуживание больших данных.
- Индексы: B‑Tree (точные значения/диапазоны), GiST (гео/диапазоны/сложные типы), GIN (множества, JSONB, полнотекст), BRIN (очень большие упорядоченные таблицы).
- Autovacuum — автоматический VACUUM/ANALYZE для удаления «мёртвых» версий строк и обновления статистики.
- ANALYZE — сбор статистики для планировщика запросов.
- SERIAL/SEQUENCE/IDENTITY — генерация первичных ключей; «дыры» в нумерации нормальны из‑за откатов/параллельности.
- Идемпотентность — возможность безопасно повторять шаги (например, `IF NOT EXISTS`, `ON CONFLICT DO NOTHING`).
- Read‑only transaction — режим, в котором DML запрещён (типично на реплике/hot standby).