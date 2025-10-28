# Инициализация баз PostgreSQL с репликацией
# Скрипт запускается после настройки pg_auto_failover

param(
    [string]$PrimaryContainer = "pgauto-node2"  # Указывается текущая основная нода после failover
)

Write-Host "🔧 Ожидание готовности основной ноды PostgreSQL..." -ForegroundColor Cyan
Write-Host "   Используемый контейнер: $PrimaryContainer" -ForegroundColor Gray
Start-Sleep -Seconds 5

Write-Host "📦 Создание баз данных..." -ForegroundColor Yellow

$createDbsSql = @"
SELECT 'CREATE DATABASE users_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'users_db')\gexec
SELECT 'CREATE DATABASE documents_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'documents_db')\gexec
SELECT 'CREATE DATABASE search_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'search_db')\gexec
SELECT 'CREATE DATABASE audit_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'audit_db')\gexec
"@

$createDbsSql | docker exec -i $PrimaryContainer psql -U docker -d postgres

Write-Host "📋 Применение схем..." -ForegroundColor Yellow

# Настройка схемы users_db
$usersSchemaSql = @"
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
"@

$usersSchemaSql | docker exec -i $PrimaryContainer psql -U docker -d users_db

# Настройка схемы documents_db
$documentsSchemaSql = @"
CREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    author VARCHAR(255),
    metadata JSONB,
    indexed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_documents_title ON documents USING GIN(to_tsvector('english', title));
CREATE INDEX IF NOT EXISTS idx_documents_indexed ON documents(indexed);
"@

$documentsSchemaSql | docker exec -i $PrimaryContainer psql -U docker -d documents_db

# Настройка схемы search_db
$searchSchemaSql = @"
CREATE TABLE IF NOT EXISTS terms (
    id SERIAL PRIMARY KEY,
    term VARCHAR(255) UNIQUE NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_terms_term ON terms(term);

CREATE TABLE IF NOT EXISTS postings (
    id SERIAL PRIMARY KEY,
    term_id INTEGER REFERENCES terms(id) ON DELETE CASCADE,
    doc_id INTEGER NOT NULL,
    positions INTEGER[],
    tf_idf FLOAT DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_postings_term_id ON postings(term_id);
CREATE INDEX IF NOT EXISTS idx_postings_doc_id ON postings(doc_id);

CREATE TABLE IF NOT EXISTS search_documents (
    id INTEGER PRIMARY KEY,
    title VARCHAR(500),
    snippet TEXT,
    indexed_at TIMESTAMP DEFAULT NOW()
);
"@

$searchSchemaSql | docker exec -i $PrimaryContainer psql -U docker -d search_db

# Настройка схемы audit_db с партициями
$auditSchemaSql = @"
CREATE TABLE IF NOT EXISTS events (
    event_id BIGSERIAL,
    aggregate_type VARCHAR(50),
    aggregate_id VARCHAR(100),
    event_type VARCHAR(50),
    event_data JSONB,
    user_id VARCHAR(100),
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (event_id, timestamp)
) PARTITION BY RANGE (timestamp);

CREATE TABLE IF NOT EXISTS events_2025_10 PARTITION OF events
    FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE IF NOT EXISTS events_2025_11 PARTITION OF events
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE IF NOT EXISTS events_2025_12 PARTITION OF events
    FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');

CREATE INDEX IF NOT EXISTS idx_events_aggregate ON events(aggregate_type, aggregate_id);
CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);
"@

$auditSchemaSql | docker exec -i $PrimaryContainer psql -U docker -d audit_db

Write-Host "✅ Базы данных и схемы подготовлены" -ForegroundColor Green
Write-Host "📊 Проверка статуса репликации..." -ForegroundColor Cyan

docker exec pgauto-monitor pg_autoctl show state

Write-Host ""
Write-Host "🎉 Репликация PostgreSQL готова" -ForegroundColor Green
