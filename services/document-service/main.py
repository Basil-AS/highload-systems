"""
Document Service - управление документами поисковой системы
"""
import os
import json
import asyncio
from datetime import datetime
from typing import Optional, List
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field
import asyncpg
import aio_pika
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response

# =====================================================
# Configuration
# =====================================================
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://docker:secret@localhost:5432/documents_db")
RABBITMQ_URL = os.getenv("RABBITMQ_URL", "amqp://guest:guest@localhost:5672/")

# =====================================================
# Prometheus metrics
# =====================================================
REQUEST_COUNT = Counter('document_service_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('document_service_request_duration_seconds', 'Request latency', ['method', 'endpoint'])
INDEXING_QUEUE_SIZE = Counter('document_indexing_queue_total', 'Documents sent to indexing queue')

# =====================================================
# Global connections
# =====================================================
db_pool: Optional[asyncpg.Pool] = None
rabbitmq_connection: Optional[aio_pika.Connection] = None
rabbitmq_channel: Optional[aio_pika.Channel] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle manager"""
    global db_pool, rabbitmq_connection, rabbitmq_channel
    
    # Database pool
    db_pool = await asyncpg.create_pool(DATABASE_URL, min_size=2, max_size=10)
    
    # Create tables
    async with db_pool.acquire() as conn:
        await conn.execute("""
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
        """)
    
    # RabbitMQ connection
    rabbitmq_connection = await aio_pika.connect_robust(RABBITMQ_URL)
    rabbitmq_channel = await rabbitmq_connection.channel()
    await rabbitmq_channel.declare_queue("indexing_queue", durable=True)
    
    yield
    
    await db_pool.close()
    await rabbitmq_connection.close()

# =====================================================
# FastAPI app
# =====================================================
app = FastAPI(
    title="Document Service",
    description="Управление документами поисковой системы (ЛР4, Вариант 8)",
    version="1.0.0",
    lifespan=lifespan
)

# =====================================================
# Models
# =====================================================
class DocumentCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=500)
    content: str = Field(..., min_length=1)
    author: Optional[str] = None
    metadata: Optional[dict] = None

class DocumentUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=500)
    content: Optional[str] = Field(None, min_length=1)
    author: Optional[str] = None
    metadata: Optional[dict] = None

class DocumentResponse(BaseModel):
    id: int
    title: str
    content: str
    author: Optional[str]
    metadata: Optional[dict]
    indexed: bool
    created_at: datetime
    updated_at: datetime

# =====================================================
# Helper functions
# =====================================================
async def send_to_indexing_queue(doc_id: int, title: str, content: str):
    """Send document to indexing queue"""
    try:
        message_body = json.dumps({
            "doc_id": doc_id,
            "title": title,
            "content": content,
            "timestamp": datetime.utcnow().isoformat()
        })
        
        message = aio_pika.Message(
            body=message_body.encode(),
            delivery_mode=aio_pika.DeliveryMode.PERSISTENT
        )
        
        await rabbitmq_channel.default_exchange.publish(
            message,
            routing_key="indexing_queue"
        )
        
        INDEXING_QUEUE_SIZE.inc()
        print(f"Document {doc_id} sent to indexing queue")
    except Exception as e:
        print(f"Failed to send document to queue: {e}")

# =====================================================
# Endpoints
# =====================================================
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        async with db_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        return {"status": "healthy", "service": "document-service"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Service unhealthy: {str(e)}")

@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.post("/api/documents", response_model=DocumentResponse, status_code=201)
async def create_document(doc: DocumentCreate):
    """Create a new document"""
    with REQUEST_LATENCY.labels(method="POST", endpoint="/api/documents").time():
        try:
            async with db_pool.acquire() as conn:
                row = await conn.fetchrow(
                    """
                    INSERT INTO documents (title, content, author, metadata)
                    VALUES ($1, $2, $3, $4)
                    RETURNING id, title, content, author, metadata, indexed, created_at, updated_at
                    """,
                    doc.title, doc.content, doc.author, json.dumps(doc.metadata) if doc.metadata else None
                )
            
            document = DocumentResponse(**dict(row))
            
            # Асинхронная отправка в очередь индексации
            asyncio.create_task(send_to_indexing_queue(document.id, document.title, document.content))
            
            REQUEST_COUNT.labels(method="POST", endpoint="/api/documents", status="success").inc()
            return document
            
        except Exception as e:
            REQUEST_COUNT.labels(method="POST", endpoint="/api/documents", status="error").inc()
            raise HTTPException(status_code=500, detail=f"Failed to create document: {str(e)}")

@app.get("/api/documents/{doc_id}", response_model=DocumentResponse)
async def get_document(doc_id: int):
    """Get document by ID"""
    with REQUEST_LATENCY.labels(method="GET", endpoint="/api/documents/{id}").time():
        async with db_pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT id, title, content, author, metadata, indexed, created_at, updated_at FROM documents WHERE id = $1",
                doc_id
            )
        
        if not row:
            REQUEST_COUNT.labels(method="GET", endpoint="/api/documents/{id}", status="error").inc()
            raise HTTPException(status_code=404, detail="Document not found")
        
        REQUEST_COUNT.labels(method="GET", endpoint="/api/documents/{id}", status="success").inc()
        return DocumentResponse(**dict(row))

@app.get("/api/documents", response_model=List[DocumentResponse])
async def list_documents(
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100)
):
    """List documents with pagination"""
    with REQUEST_LATENCY.labels(method="GET", endpoint="/api/documents").time():
        async with db_pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT id, title, content, author, metadata, indexed, created_at, updated_at
                FROM documents
                ORDER BY created_at DESC
                LIMIT $1 OFFSET $2
                """,
                limit, skip
            )
        
        REQUEST_COUNT.labels(method="GET", endpoint="/api/documents", status="success").inc()
        return [DocumentResponse(**dict(row)) for row in rows]

@app.put("/api/documents/{doc_id}", response_model=DocumentResponse)
async def update_document(doc_id: int, doc: DocumentUpdate):
    """Update document"""
    with REQUEST_LATENCY.labels(method="PUT", endpoint="/api/documents/{id}").time():
        # Build dynamic update query
        updates = []
        values = []
        param_num = 1
        
        if doc.title is not None:
            updates.append(f"title = ${param_num}")
            values.append(doc.title)
            param_num += 1
        
        if doc.content is not None:
            updates.append(f"content = ${param_num}")
            values.append(doc.content)
            param_num += 1
        
        if doc.author is not None:
            updates.append(f"author = ${param_num}")
            values.append(doc.author)
            param_num += 1
        
        if doc.metadata is not None:
            updates.append(f"metadata = ${param_num}")
            values.append(json.dumps(doc.metadata))
            param_num += 1
        
        if not updates:
            raise HTTPException(status_code=400, detail="No fields to update")
        
        updates.append(f"updated_at = NOW()")
        updates.append(f"indexed = FALSE")  # Нужна переиндексация
        values.append(doc_id)
        
        query = f"""
            UPDATE documents
            SET {', '.join(updates)}
            WHERE id = ${param_num}
            RETURNING id, title, content, author, metadata, indexed, created_at, updated_at
        """
        
        async with db_pool.acquire() as conn:
            row = await conn.fetchrow(query, *values)
        
        if not row:
            REQUEST_COUNT.labels(method="PUT", endpoint="/api/documents/{id}", status="error").inc()
            raise HTTPException(status_code=404, detail="Document not found")
        
        document = DocumentResponse(**dict(row))
        
        # Переиндексация
        asyncio.create_task(send_to_indexing_queue(document.id, document.title, document.content))
        
        REQUEST_COUNT.labels(method="PUT", endpoint="/api/documents/{id}", status="success").inc()
        return document

@app.delete("/api/documents/{doc_id}")
async def delete_document(doc_id: int):
    """Delete document"""
    with REQUEST_LATENCY.labels(method="DELETE", endpoint="/api/documents/{id}").time():
        async with db_pool.acquire() as conn:
            result = await conn.execute("DELETE FROM documents WHERE id = $1", doc_id)
        
        if result == "DELETE 0":
            REQUEST_COUNT.labels(method="DELETE", endpoint="/api/documents/{id}", status="error").inc()
            raise HTTPException(status_code=404, detail="Document not found")
        
        REQUEST_COUNT.labels(method="DELETE", endpoint="/api/documents/{id}", status="success").inc()
        return {"message": "Document deleted successfully"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
