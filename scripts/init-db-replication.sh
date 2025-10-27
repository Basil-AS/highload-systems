#!/bin/bash
# Скрипт для инициализации баз данных в PostgreSQL с репликацией
# Выполняется после настройки pg_auto_failover

set -e

echo "🔧 Waiting for PostgreSQL Primary to be ready..."
sleep 10

echo "📦 Creating databases..."
docker exec search-postgres-primary psql -U postgres <<-EOSQL
    -- Создание баз данных
    SELECT 'CREATE DATABASE users_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'users_db')\gexec
    SELECT 'CREATE DATABASE documents_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'documents_db')\gexec
    SELECT 'CREATE DATABASE search_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'search_db')\gexec
    SELECT 'CREATE DATABASE audit_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'audit_db')\gexec
EOSQL

echo "📋 Applying schemas..."

# users_db schema
docker exec search-postgres-primary psql -U postgres -d users_db <<-EOSQL
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
EOSQL

# documents_db schema
docker exec search-postgres-primary psql -U postgres -d documents_db <<-EOSQL
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
EOSQL

# search_db schema
docker exec search-postgres-primary psql -U postgres -d search_db <<-EOSQL
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
EOSQL

# audit_db schema with partitioning
docker exec search-postgres-primary psql -U postgres -d audit_db <<-EOSQL
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

    -- Create partitions for 3 months
    CREATE TABLE IF NOT EXISTS events_2025_10 PARTITION OF events
        FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
    CREATE TABLE IF NOT EXISTS events_2025_11 PARTITION OF events
        FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
    CREATE TABLE IF NOT EXISTS events_2025_12 PARTITION OF events
        FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');

    CREATE INDEX IF NOT EXISTS idx_events_aggregate ON events(aggregate_type, aggregate_id);
    CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);
EOSQL

echo "✅ Databases and schemas created successfully!"
echo "📊 Checking replication status..."
docker exec search-pg-monitor pg_autoctl show state

echo ""
echo "🎉 PostgreSQL replication is ready!"
