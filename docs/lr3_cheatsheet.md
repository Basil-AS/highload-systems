# ЛР3 — PostgreSQL: репликация, failover и денормализация (шпаргалка)

Цель: показать, что репликация работает, а для варианта 3 — что денормализованная таблица `sales_report` автоматически поддерживается триггерами и ускоряет отчёты.

## Что развёрнуто
- Кластер в Docker (`pg_cluster/`):
  - monitor: порт 5434 (`pg_autoctl`)
  - master: порт 5432 (`postgres-master`)
  - slave: порт 5433 (`postgres-slave`)
- Репликация и автоматический failover: инструмент `pg_autoctl` (pg_auto_failover)
- Вариант 3: денормализация — `products`, `orders`, `sales_report` с триггерами на INSERT/UPDATE/DELETE.

## Важные файлы в проекте
- `pg_cluster/docker-compose.yml` — монитор + 2 дата-ноды с `pg_autoctl`.
- `pg_cluster/init/master/02_schema.sql` — таблицы варианта 3, функция и триггер.
- `pg_cluster/README.md` — краткие шаги запуска.

## Как запустить (PowerShell)
```pwsh
# Поднять кластер
docker compose -f pg_cluster/docker-compose.yml up -d

# Смотреть состояние узлов (опционально)
docker compose -f pg_cluster/docker-compose.yml logs -f --tail=100 pgmonitor
```

## Демонстрация репликации (практика)
```pwsh
# На мастере: создать тестовую таблицу и запись
docker compose -f pg_cluster/docker-compose.yml exec postgres-master psql -U admin -d app_db -c "CREATE TABLE IF NOT EXISTS test (id SERIAL PRIMARY KEY, data VARCHAR); INSERT INTO test (data) VALUES ('replication_test') ON CONFLICT DO NOTHING;"

# На слейве: проверить, что запись пришла
psql -h localhost -p 5433 -U admin -d app_db -c "SELECT * FROM test;"
```
Ожидаемо: на slave1 видим строку `replication_test`.

## Вариант 3 — денормализация (практика)
```pwsh
# Очистить и заполнить тестовыми данными (мастер)
docker compose -f pg_cluster/docker-compose.yml exec postgres-master psql -U admin -d app_db -c "TRUNCATE sales_report; TRUNCATE orders RESTART IDENTITY CASCADE; TRUNCATE products RESTART IDENTITY CASCADE; INSERT INTO products(name, price) VALUES ('A',10.00),('B',5.00); INSERT INTO orders(product_id, quantity) VALUES (1,3),(2,4); SELECT * FROM sales_report ORDER BY product_name;"

# На слейве: проверки отчёта
psql -h localhost -p 5433 -U admin -d app_db -c "SELECT * FROM sales_report ORDER BY product_name;"
```
Ожидаемо: `A: qty=3, revenue=30.00` и `B: qty=4, revenue=20.00` видны и на мастере, и на слейве.

### Показать пользу денормализации
- Нормализованный запрос (агрегация на лету):
```sql
SELECT p.name, SUM(o.quantity) AS total_quantity, SUM(o.quantity * p.price) AS total_revenue
FROM orders o
JOIN products p ON p.id = o.product_id
GROUP BY p.name
ORDER BY p.name;
```
- Денормализованный (мгновенный):
```sql
SELECT * FROM sales_report ORDER BY product_name;
```
- Сравнение: запустить оба с `EXPLAIN ANALYZE` (на мастере и/или слейве) и проговорить, что для больших объёмов `sales_report` снимает нагрузку с агрегаций на горячем пути отчётов.

## Failover (по заданию)
- Инструмент уже подключён: `pg_autoctl`.
- Имитация сбоя мастера:
```pwsh
docker stop postgres-master
```
- Проверка, что слейв стал мастером (простая запись):
```pwsh
docker exec -it postgres-slave psql -U admin -d app_db -c "INSERT INTO test(data) VALUES ('after_failover');"
```
- Возврат узла и автоматическое восстановление как реплики:
```pwsh
docker start postgres-master
```

## Ответы на контрольные вопросы
1) Синхронная vs асинхронная: синхронная ждёт подтверждения реплики — выше надёжность, ниже latency/throughput; асинхронная быстрее, но возможна потеря последних транзакций при падении мастера.
2) Индексы для диапазонов: B-Tree (по умолчанию) хорошо для типичных диапазонов; для геометрии/диапазонов по сложным типам — GiST; для очень больших упорядоченных таблиц — BRIN (компактный, быстрый по диапазонам страниц).
3) Почему денормализация может ухудшить целостность: данные дублируются, требуется доп. логика синхронизации (триггеры/процедуры); риск рассинхронизации при ошибках, сложнее транзакционные гарантии.
4) Партиционирование и производительность: уменьшает объём сканирования (partition pruning), ускоряет DML и maintenance на больших объёмах; но усложняет планы и требует правильного ключа партиций.
5) Параметры PostgreSQL для OLTP: `shared_buffers`, `effective_cache_size`, `work_mem`, `maintenance_work_mem`, `checkpoint_timeout`, `max_wal_size`, `synchronous_commit`, настройки `autovacuum`;
   также важны диски (latency) и конфигурация WAL/FSync.

## Подсказки
- Если узлы не поднимаются: проверь логи `pgmonitor` и состояние контейнеров, дождись готовности мониторинга (порт 5434).
- Предупреждение в compose про `version` можно игнорировать (косметика) или убрать ключ `version`.
- Для «красивой» защиты: подготовь заранее пару скриншотов `EXPLAIN ANALYZE` нормализованного vs денормализованного запроса на объёме.
