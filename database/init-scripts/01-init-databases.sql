-- Мы создаём базы для сервисов.
-- Схемы добавим позже в 02-create-schemas.sql.

-- Мы создаём базу user-сервиса.
CREATE DATABASE users_db;

-- Мы создаём базу document-сервиса.
CREATE DATABASE documents_db;

-- Мы создаём базу search-сервиса.
CREATE DATABASE search_db;

-- Мы создаём базу аудит-сервиса.
CREATE DATABASE audit_db;

-- Мы выводим подсказку в консоль.
\echo 'Создали базы: users_db, documents_db, search_db, audit_db'
