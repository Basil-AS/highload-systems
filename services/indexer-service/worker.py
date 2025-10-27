"""
Indexer Worker - асинхронная индексация документов
Читает сообщения из RabbitMQ и строит inverted index
"""
import os
import json
import asyncio
import re
from collections import Counter
from typing import List, Dict

import asyncpg
import aio_pika
import redis.asyncio as aioredis

# =====================================================
# Configuration
# =====================================================
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://docker:secret@localhost:5432/search_db")
RABBITMQ_URL = os.getenv("RABBITMQ_URL", "amqp://guest:guest@localhost:5672/")
VALKEY_URL = os.getenv("VALKEY_URL", "redis://localhost:6379/1")

# =====================================================
# Text processing
# =====================================================
STOPWORDS = set([
    'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'for', 'from',
    'has', 'he', 'in', 'is', 'it', 'its', 'of', 'on', 'that', 'the',
    'to', 'was', 'will', 'with'
])

def tokenize(text: str) -> List[str]:
    """Tokenize text into words"""
    # Lowercase and remove punctuation
    text = text.lower()
    text = re.sub(r'[^\w\s]', ' ', text)
    
    # Split into words
    words = text.split()
    
    # Remove stopwords and short words
    tokens = [w for w in words if w not in STOPWORDS and len(w) > 2]
    
    return tokens

def calculate_tf(tokens: List[str]) -> Dict[str, float]:
    """Calculate term frequency"""
    if not tokens:
        return {}
    
    counter = Counter(tokens)
    total = len(tokens)
    
    return {term: count / total for term, count in counter.items()}

# =====================================================
# Database operations
# =====================================================
async def get_or_create_term(conn: asyncpg.Connection, term: str) -> int:
    """Get term ID or create if not exists"""
    # Try to get existing
    term_id = await conn.fetchval("SELECT id FROM terms WHERE term = $1", term)
    
    if term_id:
        return term_id
    
    # Create new
    try:
        term_id = await conn.fetchval(
            "INSERT INTO terms (term) VALUES ($1) RETURNING id",
            term
        )
        return term_id
    except asyncpg.UniqueViolationError:
        # Race condition - another worker created it
        term_id = await conn.fetchval("SELECT id FROM terms WHERE term = $1", term)
        return term_id

async def index_document(
    db_pool: asyncpg.Pool,
    redis_client: aioredis.Redis,
    doc_id: int,
    title: str,
    content: str
):
    """Index a document"""
    print(f"Indexing document {doc_id}: {title[:50]}...")
    
    # Tokenize title and content
    all_text = f"{title} {content}"
    tokens = tokenize(all_text)
    
    if not tokens:
        print(f"No tokens found in document {doc_id}")
        return
    
    # Calculate term frequencies
    tf_scores = calculate_tf(tokens)
    
    async with db_pool.acquire() as conn:
        # Start transaction
        async with conn.transaction():
            # Store document metadata
            snippet = content[:200] + "..." if len(content) > 200 else content
            await conn.execute(
                """
                INSERT INTO search_documents (id, title, snippet, indexed_at)
                VALUES ($1, $2, $3, NOW())
                ON CONFLICT (id) DO UPDATE
                SET title = EXCLUDED.title, snippet = EXCLUDED.snippet, indexed_at = NOW()
                """,
                doc_id, title, snippet
            )
            
            # Delete old postings for this document
            await conn.execute("DELETE FROM postings WHERE doc_id = $1", doc_id)
            
            # Insert new postings
            for term, tf in tf_scores.items():
                term_id = await get_or_create_term(conn, term)
                
                # Find positions of this term in the text
                positions = [i for i, t in enumerate(tokens) if t == term]
                
                # Simple TF-IDF score (just TF for now, IDF calculation requires document count)
                score = tf
                
                await conn.execute(
                    """
                    INSERT INTO postings (term_id, doc_id, positions, tf_idf)
                    VALUES ($1, $2, $3, $4)
                    """,
                    term_id, doc_id, positions, score
                )
            
            # Mark document as indexed in documents table
            await conn.execute(
                "UPDATE documents SET indexed = TRUE WHERE id = $1",
                doc_id
            )
            
            print(f"Document {doc_id} indexed successfully with {len(tf_scores)} unique terms")
    
    # Invalidate cache for search queries
    try:
        # Clear all search cache (simple approach)
        cursor = 0
        while True:
            cursor, keys = await redis_client.scan(cursor, match="*", count=100)
            if keys:
                await redis_client.delete(*keys)
            if cursor == 0:
                break
        print(f"Cache invalidated after indexing document {doc_id}")
    except Exception as e:
        print(f"Failed to invalidate cache: {e}")

# =====================================================
# Worker main loop
# =====================================================
async def process_message(
    message: aio_pika.IncomingMessage,
    db_pool: asyncpg.Pool,
    redis_client: aioredis.Redis
):
    """Process a single message from the queue"""
    async with message.process():
        try:
            data = json.loads(message.body.decode())
            doc_id = data["doc_id"]
            title = data["title"]
            content = data["content"]
            
            await index_document(db_pool, redis_client, doc_id, title, content)
            
        except Exception as e:
            print(f"Error processing message: {e}")
            # Message will be requeued automatically if we raise an exception
            raise

async def main():
    """Main worker loop"""
    print(f"Indexer Worker starting...")
    print(f"Database: {DATABASE_URL}")
    print(f"RabbitMQ: {RABBITMQ_URL}")
    print(f"ValKey: {VALKEY_URL}")
    
    # Wait a bit for services to be fully ready
    print("Waiting 5 seconds for services to be ready...")
    await asyncio.sleep(5)
    
    # Connect to database
    db_pool = await asyncpg.create_pool(DATABASE_URL, min_size=1, max_size=5)
    print("Connected to database")
    
    # Connect to Redis
    redis_client = await aioredis.from_url(VALKEY_URL, decode_responses=True)
    print("Connected to ValKey")
    
    # Connect to RabbitMQ with retry
    max_retries = 5
    for attempt in range(max_retries):
        try:
            connection = await aio_pika.connect_robust(RABBITMQ_URL)
            break
        except Exception as e:
            if attempt < max_retries - 1:
                wait_time = 2 ** attempt
                print(f"RabbitMQ connection failed (attempt {attempt + 1}/{max_retries}), retrying in {wait_time}s...")
                await asyncio.sleep(wait_time)
            else:
                raise
    
    channel = await connection.channel()
    await channel.set_qos(prefetch_count=1)  # Process one message at a time
    
    queue = await channel.declare_queue("indexing_queue", durable=True)
    print(f"Connected to RabbitMQ, listening on queue 'indexing_queue'")
    
    # Start consuming
    print("Worker ready, waiting for messages...")
    async with queue.iterator() as queue_iter:
        async for message in queue_iter:
            await process_message(message, db_pool, redis_client)
    
    # Cleanup (won't reach here in normal operation)
    await db_pool.close()
    await redis_client.close()
    await connection.close()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nWorker stopped by user")
    except Exception as e:
        print(f"Worker crashed: {e}")
        raise
