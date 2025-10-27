-- Инициализация баз данных для всех микросервисов
-- Схемы таблиц создаются в 02-create-schemas.sql

-- База данных для User Service
CREATE DATABASE users_db;

-- База данных для Document Service
CREATE DATABASE documents_db;

-- База данных для Search Service (инвертированный индекс)
CREATE DATABASE search_db;

-- База данных для Audit Service (Event Sourcing)
CREATE DATABASE audit_db;

-- Вывод информации
\echo 'Databases created:'
\echo '  - users_db: User Service data'
\echo '  - documents_db: Document Service data'
\echo '  - search_db: Search Service inverted index'
\echo '  - audit_db: Audit Service event store with partitioning'
