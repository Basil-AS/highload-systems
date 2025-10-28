"""
Мы индексируем документы и читаем очереди.
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

# Мы задаём настройки подключения
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://docker:secret@localhost:5432/search_db")
RABBITMQ_URL = os.getenv("RABBITMQ_URL", "amqp://guest:guest@localhost:5672/")
VALKEY_URL = os.getenv("VALKEY_URL", "redis://localhost:6379/1")

# Мы готовим обработку текста
STOPWORDS = set([
    'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'for', 'from',
    'has', 'he', 'in', 'is', 'it', 'its', 'of', 'on', 'that', 'the',
    'to', 'was', 'will', 'with'
])

def tokenize(text: str) -> List[str]:
    """Мы разбиваем текст на слова."""
    # Мы приводим к нижнему регистру и убираем знаки
    text = text.lower()
    text = re.sub(r'[^\w\s]', ' ', text)
    
    # Мы делим на слова
    words = text.split()
    
    # Мы убираем стоп-слова и короткие слова
    tokens = [w for w in words if w not in STOPWORDS and len(w) > 2]
    
    return tokens

def calculate_tf(tokens: List[str]) -> Dict[str, float]:
    """Мы считаем частоты слов."""
    if not tokens:
        return {}
    
    counter = Counter(tokens)
    total = len(tokens)
    
    return {term: count / total for term, count in counter.items()}

# Мы работаем с базой данных
async def get_or_create_term(conn: asyncpg.Connection, term: str) -> int:
    """Мы получаем id термина или создаём его."""
    # Мы пытаемся найти существующий термин
    term_id = await conn.fetchval("SELECT id FROM terms WHERE term = $1", term)
    
    if term_id:
        return term_id
    
    # Мы создаём новый термин
    try:
        term_id = await conn.fetchval(
            "INSERT INTO terms (term) VALUES ($1) RETURNING id",
            term
        )
        return term_id
    except asyncpg.UniqueViolationError:
    # Мы отлавливаем ситуацию гонки
        term_id = await conn.fetchval("SELECT id FROM terms WHERE term = $1", term)
        return term_id

async def index_document(
    db_pool: asyncpg.Pool,
    redis_client: aioredis.Redis,
    doc_id: int,
    title: str,
    content: str
):
    """Мы индексируем документ."""
    print(f"Indexing document {doc_id}: {title[:50]}...")
    
    # Мы готовим текст
    all_text = f"{title} {content}"
    tokens = tokenize(all_text)
    
    if not tokens:
        print(f"No tokens found in document {doc_id}")
        return
    
    # Мы считаем частоты терминов
    tf_scores = calculate_tf(tokens)
    
    async with db_pool.acquire() as conn:
        # Мы запускаем транзакцию
        async with conn.transaction():
            # Мы сохраняем метаданные документа
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
            
            # Мы удаляем старые записи по документу
            await conn.execute("DELETE FROM postings WHERE doc_id = $1", doc_id)
            
            # Мы вставляем новые записи
            for term, tf in tf_scores.items():
                term_id = await get_or_create_term(conn, term)
                
                # Мы ищем позиции термина
                positions = [i for i, t in enumerate(tokens) if t == term]
                
                # Мы используем простую оценку TF
                score = tf
                
                await conn.execute(
                    """
                    INSERT INTO postings (term_id, doc_id, positions, tf_idf)
                    VALUES ($1, $2, $3, $4)
                    """,
                    term_id, doc_id, positions, score
                )
            
            # Мы отмечаем документ как проиндексированный
            await conn.execute(
                "UPDATE documents SET indexed = TRUE WHERE id = $1",
                doc_id
            )
            
            print(f"Document {doc_id} indexed successfully with {len(tf_scores)} unique terms")
    
    # Мы инвалидируем кеш
    try:
    # Мы очищаем весь кеш
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

# Мы запускаем цикл воркера
async def process_message(
    message: aio_pika.IncomingMessage,
    db_pool: asyncpg.Pool,
    redis_client: aioredis.Redis
):
    """Мы разбираем одно сообщение очереди."""
    async with message.process():
        try:
            data = json.loads(message.body.decode())
            doc_id = data["doc_id"]
            title = data["title"]
            content = data["content"]
            
            await index_document(db_pool, redis_client, doc_id, title, content)
            
        except Exception as e:
            print(f"Error processing message: {e}")
        # Мы знаем что сообщение повторится если поднимем исключение
            raise

async def main():
    """Мы запускаем основной цикл."""
    print(f"Indexer Worker starting...")
    print(f"Database: {DATABASE_URL}")
    print(f"RabbitMQ: {RABBITMQ_URL}")
    print(f"ValKey: {VALKEY_URL}")
    
    # Мы ждём пока сервисы поднимутся
    print("Waiting 5 seconds for services to be ready...")
    await asyncio.sleep(5)
    
    # Мы подключаемся к базе
    db_pool = await asyncpg.create_pool(DATABASE_URL, min_size=1, max_size=5)
    print("Connected to database")
    
    # Мы подключаемся к ValKey
    redis_client = await aioredis.from_url(VALKEY_URL, decode_responses=True)
    print("Connected to ValKey")
    
    # Мы подключаемся к RabbitMQ с повторами
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
    await channel.set_qos(prefetch_count=1)  # Мы обрабатываем по одному сообщению
    
    queue = await channel.declare_queue("indexing_queue", durable=True)
    print(f"Connected to RabbitMQ, listening on queue 'indexing_queue'")
    
    # Мы запускаем чтение очереди
    print("Worker ready, waiting for messages...")
    async with queue.iterator() as queue_iter:
        async for message in queue_iter:
            await process_message(message, db_pool, redis_client)
    
    # Мы чисто закрываем подключения (почти не доходим сюда)
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
