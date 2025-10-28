"""
Сервис поиска. Мы отвечаем за полнотекстовые запросы.
"""
import os
import json
import hashlib
from datetime import datetime
from typing import List, Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
import asyncpg
import redis.asyncio as aioredis
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response

# Мы задаём настройки подключения
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://docker:secret@localhost:5432/app_db")
VALKEY_URL = os.getenv("VALKEY_URL", "redis://localhost:6379/1")
CACHE_TTL = 300  # мы держим кеш 5 минут

# Мы объявляем метрики Prometheus
REQUEST_COUNT = Counter('search_service_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('search_service_request_duration_seconds', 'Request latency', ['method', 'endpoint'])
CACHE_HIT = Counter('search_cache_hits_total', 'Cache hits')
CACHE_MISS = Counter('search_cache_misses_total', 'Cache misses')
SEARCH_RESULTS = Histogram('search_results_count', 'Number of search results')

# Мы держим глобальные подключения
db_pool: Optional[asyncpg.Pool] = None
redis_client: Optional[aioredis.Redis] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Мы поднимаем подключения и закрываем их."""
    global db_pool, redis_client
    
    # Мы создаём пул соединений
    db_pool = await asyncpg.create_pool(DATABASE_URL, min_size=5, max_size=20)
    
    # Мы создаём таблицы и индексы
    async with db_pool.acquire() as conn:
        await conn.execute("""
            -- Таблица терминов (слов)
            CREATE TABLE IF NOT EXISTS terms (
                id SERIAL PRIMARY KEY,
                term VARCHAR(255) UNIQUE NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_terms_term ON terms(term);
            
            -- Таблица постингов (inverted index)
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
            
            -- Таблица документов (минимальная информация для поиска)
            CREATE TABLE IF NOT EXISTS search_documents (
                id INTEGER PRIMARY KEY,
                title VARCHAR(500),
                snippet TEXT,
                indexed_at TIMESTAMP DEFAULT NOW()
            );
        """)
    
    # Мы подключаемся к ValKey
    redis_client = await aioredis.from_url(VALKEY_URL, decode_responses=True)
    
    yield
    
    await db_pool.close()
    await db_pool.close()
    await redis_client.close()

# Мы создаём приложение FastAPI
app = FastAPI(
    title="Search Service",
    description="Полнотекстовый поиск по документам (ЛР4, Вариант 8)",
    version="1.0.0",
    lifespan=lifespan
)

# Мы описываем модели ответов
class SearchResult(BaseModel):
    doc_id: int
    title: str
    snippet: str
    score: float
    indexed_at: datetime

class SearchResponse(BaseModel):
    query: str
    results: List[SearchResult]
    total: int
    cached: bool
    query_time_ms: float

# Мы описываем вспомогательные функции
def generate_cache_key(query: str, limit: int) -> str:
    """Мы генерируем ключ кеша."""
    key_string = f"search:{query.lower().strip()}:{limit}"
    return hashlib.md5(key_string.encode()).hexdigest()

async def search_in_database(query: str, limit: int) -> List[dict]:
    """Мы выполняем поиск в базе."""
    # Мы ищем по совпадению слов в заголовке и сниппете
    # В реальности тут был бы поиск через inverted index
    search_terms = query.lower().split()
    
    if not search_terms:
        return []
    
    # Мы используем встроенный full-text search
    async with db_pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT 
                sd.id as doc_id,
                sd.title,
                sd.snippet,
                sd.indexed_at,
                ts_rank(
                    to_tsvector('english', sd.title || ' ' || sd.snippet),
                    plainto_tsquery('english', $1)
                ) as score
            FROM search_documents sd
            WHERE to_tsvector('english', sd.title || ' ' || sd.snippet) @@ plainto_tsquery('english', $1)
            ORDER BY score DESC
            LIMIT $2
            """,
            query, limit
        )
    
    return [dict(row) for row in rows]

# Мы описываем HTTP-эндпоинты
@app.get("/health")
async def health_check():
    """Мы подтверждаем что сервис работает."""
    try:
        async with db_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        await redis_client.ping()
        return {"status": "healthy", "service": "search-service"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Service unhealthy: {str(e)}")

@app.get("/metrics")
async def metrics():
    """Мы отдаём метрики Prometheus."""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/api/search", response_model=SearchResponse)
async def search(
    q: str = Query(..., min_length=1, description="Search query"),
    limit: int = Query(10, ge=1, le=100, description="Max results")
):
    """Мы ищем документы."""
    start_time = datetime.utcnow()
    
    with REQUEST_LATENCY.labels(method="GET", endpoint="/api/search").time():
        cache_key = generate_cache_key(q, limit)
        
        # Мы сперва пробуем кеш
        try:
            cached_result = await redis_client.get(cache_key)
            if cached_result:
                CACHE_HIT.inc()
                result = json.loads(cached_result)
                result["cached"] = True
                result["query_time_ms"] = (datetime.utcnow() - start_time).total_seconds() * 1000
                REQUEST_COUNT.labels(method="GET", endpoint="/api/search", status="success").inc()
                return SearchResponse(**result)
        except Exception as e:
            print(f"Cache read error: {e}")
        
        CACHE_MISS.inc()
        
        # Мы ищем в базе
        try:
            results = await search_in_database(q, limit)
            
            search_results = [
                SearchResult(
                    doc_id=r["doc_id"],
                    title=r["title"],
                    snippet=r["snippet"],
                    score=float(r["score"]),
                    indexed_at=r["indexed_at"]
                )
                for r in results
            ]
            
            SEARCH_RESULTS.observe(len(search_results))
            
            response_data = {
                "query": q,
                "results": [r.model_dump() for r in search_results],
                "total": len(search_results),
                "cached": False,
                "query_time_ms": (datetime.utcnow() - start_time).total_seconds() * 1000
            }
            
            # Мы сохраняем результат в кеш
            try:
                await redis_client.setex(
                    cache_key,
                    CACHE_TTL,
                    json.dumps(response_data, default=str)
                )
            except Exception as e:
                print(f"Cache write error: {e}")
            
            REQUEST_COUNT.labels(method="GET", endpoint="/api/search", status="success").inc()
            return SearchResponse(**response_data)
            
        except Exception as e:
            REQUEST_COUNT.labels(method="GET", endpoint="/api/search", status="error").inc()
            raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")

@app.get("/api/search/suggestions")
async def search_suggestions(
    q: str = Query(..., min_length=1, description="Search prefix"),
    limit: int = Query(5, ge=1, le=20)
):
    """Мы подсказываем варианты для автодополнения."""
    with REQUEST_LATENCY.labels(method="GET", endpoint="/api/search/suggestions").time():
        try:
            async with db_pool.acquire() as conn:
                rows = await conn.fetch(
                    """
                    SELECT DISTINCT title
                    FROM search_documents
                    WHERE title ILIKE $1
                    LIMIT $2
                    """,
                    f"%{q}%", limit
                )
            
            suggestions = [row["title"] for row in rows]
            REQUEST_COUNT.labels(method="GET", endpoint="/api/search/suggestions", status="success").inc()
            return {"query": q, "suggestions": suggestions}
            
        except Exception as e:
            REQUEST_COUNT.labels(method="GET", endpoint="/api/search/suggestions", status="error").inc()
            raise HTTPException(status_code=500, detail=f"Suggestions failed: {str(e)}")

@app.delete("/api/search/cache")
async def clear_cache():
    """Мы чистим кеш поиска."""
    try:
        # Мы удаляем все ключи
        cursor = 0
        deleted = 0
        while True:
            cursor, keys = await redis_client.scan(cursor, match="*", count=100)
            if keys:
                deleted += await redis_client.delete(*keys)
            if cursor == 0:
                break
        
        return {"message": f"Cache cleared, {deleted} keys deleted"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Cache clear failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
