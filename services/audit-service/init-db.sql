-- Event Sourcing database with TIME-BASED PARTITIONING
-- This script creates a partitioned events table for Event Sourcing pattern
-- Partitioning strategy: BY RANGE (timestamp) - monthly partitions

-- Create database if not exists (run as superuser)
-- SELECT 'CREATE DATABASE audit_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'audit_db')\gexec

-- Connect to audit_db
\c audit_db

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_partman";

-- Drop existing table if exists (for clean setup)
DROP TABLE IF EXISTS events CASCADE;

-- Create PARTITIONED events table
-- Partition key: timestamp (monthly partitions)
CREATE TABLE events (
    id UUID DEFAULT uuid_generate_v4(),
    aggregate_type VARCHAR(50) NOT NULL,  -- 'user', 'document', 'search'
    aggregate_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(50) NOT NULL,      -- 'created', 'updated', 'deleted'
    event_data JSONB NOT NULL,
    user_id VARCHAR(255),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Composite primary key includes partition key
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

-- Create indexes on partitioned table
-- GIN index for JSONB searching
CREATE INDEX idx_events_event_data ON events USING GIN (event_data);

-- B-tree indexes for common queries
CREATE INDEX idx_events_aggregate ON events (aggregate_type, aggregate_id, timestamp);
CREATE INDEX idx_events_user ON events (user_id, timestamp) WHERE user_id IS NOT NULL;
CREATE INDEX idx_events_type ON events (event_type, timestamp);

-- Create partitions for 2024-2026 (3 years coverage)
-- Each partition covers one month

-- 2024 partitions (October - December)
CREATE TABLE events_2024_10 PARTITION OF events
    FOR VALUES FROM ('2024-10-01') TO ('2024-11-01');

CREATE TABLE events_2024_11 PARTITION OF events
    FOR VALUES FROM ('2024-11-01') TO ('2024-12-01');

CREATE TABLE events_2024_12 PARTITION OF events
    FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');

-- 2025 partitions (full year)
CREATE TABLE events_2025_01 PARTITION OF events
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE events_2025_02 PARTITION OF events
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

CREATE TABLE events_2025_03 PARTITION OF events
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

CREATE TABLE events_2025_04 PARTITION OF events
    FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');

CREATE TABLE events_2025_05 PARTITION OF events
    FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');

CREATE TABLE events_2025_06 PARTITION OF events
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');

CREATE TABLE events_2025_07 PARTITION OF events
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');

CREATE TABLE events_2025_08 PARTITION OF events
    FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');

CREATE TABLE events_2025_09 PARTITION OF events
    FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');

CREATE TABLE events_2025_10 PARTITION OF events
    FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');

CREATE TABLE events_2025_11 PARTITION OF events
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');

CREATE TABLE events_2025_12 PARTITION OF events
    FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');

-- 2026 partitions (full year)
CREATE TABLE events_2026_01 PARTITION OF events
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE events_2026_02 PARTITION OF events
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

CREATE TABLE events_2026_03 PARTITION OF events
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE events_2026_04 PARTITION OF events
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE events_2026_05 PARTITION OF events
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

CREATE TABLE events_2026_06 PARTITION OF events
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

CREATE TABLE events_2026_07 PARTITION OF events
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');

CREATE TABLE events_2026_08 PARTITION OF events
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

CREATE TABLE events_2026_09 PARTITION OF events
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');

CREATE TABLE events_2026_10 PARTITION OF events
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');

CREATE TABLE events_2026_11 PARTITION OF events
    FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');

CREATE TABLE events_2026_12 PARTITION OF events
    FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

-- Create a view to check partition sizes
CREATE OR REPLACE VIEW partition_info AS
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    (SELECT count(*) FROM pg_class c WHERE c.relname = tablename) AS row_count
FROM pg_tables
WHERE tablename LIKE 'events_%'
ORDER BY tablename;

-- Create function to automatically create future partitions
CREATE OR REPLACE FUNCTION create_next_partition()
RETURNS void AS $$
DECLARE
    last_date DATE;
    next_date DATE;
    next_month DATE;
    partition_name TEXT;
BEGIN
    -- Find the last partition date
    SELECT MAX(TO_DATE(SUBSTRING(tablename FROM '\d{4}_\d{2}'), 'YYYY_MM'))
    INTO last_date
    FROM pg_tables
    WHERE tablename LIKE 'events_%';
    
    -- Calculate next month
    next_date := last_date + INTERVAL '1 month';
    next_month := next_date + INTERVAL '1 month';
    
    -- Generate partition name
    partition_name := 'events_' || TO_CHAR(next_date, 'YYYY_MM');
    
    -- Create partition
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF events FOR VALUES FROM (%L) TO (%L)',
        partition_name,
        next_date,
        next_month
    );
    
    RAISE NOTICE 'Created partition: %', partition_name;
END;
$$ LANGUAGE plpgsql;

-- Create function to drop old partitions (older than 2 years)
CREATE OR REPLACE FUNCTION drop_old_partitions()
RETURNS void AS $$
DECLARE
    partition_record RECORD;
    partition_date DATE;
    cutoff_date DATE := NOW() - INTERVAL '2 years';
BEGIN
    FOR partition_record IN
        SELECT tablename
        FROM pg_tables
        WHERE tablename LIKE 'events_%'
    LOOP
        -- Extract date from partition name (events_2024_10 -> 2024-10-01)
        BEGIN
            partition_date := TO_DATE(SUBSTRING(partition_record.tablename FROM '\d{4}_\d{2}'), 'YYYY_MM');
            
            IF partition_date < cutoff_date THEN
                EXECUTE format('DROP TABLE IF EXISTS %I', partition_record.tablename);
                RAISE NOTICE 'Dropped old partition: %', partition_record.tablename;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Could not process partition: %', partition_record.tablename;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

-- Insert test events to verify partitioning works
INSERT INTO events (aggregate_type, aggregate_id, event_type, event_data, timestamp)
VALUES 
    ('user', 'user-001', 'created', '{"name": "John Doe", "email": "john@example.com"}', '2024-10-15'::timestamptz),
    ('user', 'user-001', 'updated', '{"email": "john.doe@example.com"}', '2024-11-20'::timestamptz),
    ('document', 'doc-001', 'created', '{"title": "Test Document"}', '2025-01-10'::timestamptz),
    ('user', 'user-002', 'created', '{"name": "Jane Smith"}', '2025-06-15'::timestamptz),
    ('search', 'search-001', 'created', '{"query": "test"}', '2025-12-20'::timestamptz);

-- Verify partitioning
SELECT 
    tableoid::regclass AS partition_name,
    count(*) as row_count
FROM events
GROUP BY tableoid
ORDER BY partition_name;

-- Display partition info
SELECT * FROM partition_info;

COMMENT ON TABLE events IS 'Event Sourcing table with time-based partitioning (monthly)';
COMMENT ON COLUMN events.aggregate_type IS 'Type of aggregate: user, document, search';
COMMENT ON COLUMN events.aggregate_id IS 'Unique identifier of the aggregate';
COMMENT ON COLUMN events.event_type IS 'Type of event: created, updated, deleted';
COMMENT ON COLUMN events.event_data IS 'Event payload as JSONB';
COMMENT ON FUNCTION create_next_partition() IS 'Automatically creates next month partition';
COMMENT ON FUNCTION drop_old_partitions() IS 'Drops partitions older than 2 years';
