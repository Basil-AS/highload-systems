from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
import asyncpg
import os
import json
from datetime import datetime
import aio_pika
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response

app = FastAPI(title="Audit Service", version="1.0.0")

# Мы объявляем метрики Prometheus
events_recorded = Counter('audit_events_recorded_total', 'Total events recorded', ['aggregate_type', 'event_type'])
replay_requests = Counter('audit_replay_requests_total', 'Total replay requests', ['aggregate_type'])
replay_duration = Histogram('audit_replay_duration_seconds', 'Replay duration')

# Мы держим подключения к базе и очереди
db_pool = None
rabbitmq_connection = None
rabbitmq_channel = None

# Мы описываем модели данных
class AuditEvent(BaseModel):
    aggregate_type: str  # мы ожидаем значения user, document или search
    aggregate_id: str
    event_type: str  # мы используем created, updated или deleted
    event_data: dict
    user_id: Optional[str] = None

class ReplayResponse(BaseModel):
    aggregate_id: str
    aggregate_type: str
    current_state: dict
    events_count: int

@app.on_event("startup")
async def startup():
    global db_pool, rabbitmq_connection, rabbitmq_channel
    
    # Мы открываем пул соединений с базой
    database_url = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@postgres-primary:5432/audit_db")
    db_pool = await asyncpg.create_pool(database_url, min_size=2, max_size=10)
    
    # Мы подключаемся к RabbitMQ
    rabbitmq_url = os.getenv("RABBITMQ_URL", "amqp://admin:admin@rabbitmq:5672/")
    rabbitmq_connection = await aio_pika.connect_robust(rabbitmq_url)
    rabbitmq_channel = await rabbitmq_connection.channel()
    
    # Мы объявляем очередь аудита
    await rabbitmq_channel.declare_queue("audit_events", durable=True)
    
    # Мы запускаем обработку сообщений
    queue = await rabbitmq_channel.get_queue("audit_events")
    await queue.consume(process_audit_event)
    
    print("Audit Service started successfully")

@app.on_event("shutdown")
async def shutdown():
    if db_pool:
        await db_pool.close()
    if rabbitmq_connection:
        await rabbitmq_connection.close()

async def process_audit_event(message: aio_pika.IncomingMessage):
    """Мы разбираем события из очереди."""
    async with message.process():
        try:
            event_data = json.loads(message.body.decode())
            await record_event(AuditEvent(**event_data))
        except Exception as e:
            print(f"Error processing audit event: {e}")

@app.post("/events", status_code=201)
async def record_event(event: AuditEvent):
    """Мы сохраняем событие аудита."""
    try:
        async with db_pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO events (aggregate_type, aggregate_id, event_type, event_data, user_id)
                VALUES ($1, $2, $3, $4, $5)
            """, event.aggregate_type, event.aggregate_id, event.event_type, 
            json.dumps(event.event_data), event.user_id)
        
        # Мы обновляем метрики
        events_recorded.labels(
            aggregate_type=event.aggregate_type,
            event_type=event.event_type
        ).inc()
        
        return {"status": "recorded", "event_id": event.aggregate_id}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to record event: {str(e)}")

@app.get("/replay/{aggregate_type}/{aggregate_id}", response_model=ReplayResponse)
async def replay_events(aggregate_type: str, aggregate_id: str):
    """Мы восстанавливаем состояние по событиям."""
    
    with replay_duration.time():
        try:
            async with db_pool.acquire() as conn:
                # Мы достаём все события по сущности
                events = await conn.fetch("""
                    SELECT event_type, event_data, timestamp
                    FROM events
                    WHERE aggregate_type = $1 AND aggregate_id = $2
                    ORDER BY timestamp ASC
                """, aggregate_type, aggregate_id)
            
            if not events:
                raise HTTPException(status_code=404, detail="No events found for this aggregate")
            
            # Мы прокручиваем события чтобы получить состояние
            state = {}
            for event in events:
                event_type = event['event_type']
                event_data = json.loads(event['event_data']) if isinstance(event['event_data'], str) else event['event_data']
                
                if event_type == 'created':
                    state = event_data
                elif event_type == 'updated':
                    state.update(event_data)
                elif event_type == 'deleted':
                    state = {'deleted': True, 'deleted_at': event['timestamp'].isoformat()}
            
            # Мы обновляем метрики
            replay_requests.labels(aggregate_type=aggregate_type).inc()
            
            return ReplayResponse(
                aggregate_id=aggregate_id,
                aggregate_type=aggregate_type,
                current_state=state,
                events_count=len(events)
            )
        
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to replay events: {str(e)}")

@app.get("/events/{aggregate_type}/{aggregate_id}")
async def get_events(
    aggregate_type: str, 
    aggregate_id: str,
    limit: int = 100,
    offset: int = 0
):
    """Мы отдаём события по сущности."""
    try:
        async with db_pool.acquire() as conn:
            events = await conn.fetch("""
                SELECT event_id, event_type, event_data, user_id, timestamp
                FROM events
                WHERE aggregate_type = $1 AND aggregate_id = $2
                ORDER BY timestamp DESC
                LIMIT $3 OFFSET $4
            """, aggregate_type, aggregate_id, limit, offset)
        
        return {
            "events": [
                {
                    "event_id": e['event_id'],
                    "event_type": e['event_type'],
                    "event_data": e['event_data'],
                    "user_id": str(e['user_id']) if e['user_id'] else None,
                    "timestamp": e['timestamp'].isoformat()
                }
                for e in events
            ],
            "count": len(events)
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get events: {str(e)}")

@app.get("/stats")
async def get_stats():
    """Мы отдаём статистику по аудиту."""
    try:
        async with db_pool.acquire() as conn:
            stats = await conn.fetchrow("""
                SELECT 
                    COUNT(*) as total_events,
                    COUNT(DISTINCT aggregate_id) as total_aggregates,
                    COUNT(DISTINCT aggregate_type) as total_types
                FROM events
            """)
            
            by_type = await conn.fetch("""
                SELECT aggregate_type, COUNT(*) as count
                FROM events
                GROUP BY aggregate_type
                ORDER BY count DESC
            """)
        
        return {
            "total_events": stats['total_events'],
            "total_aggregates": stats['total_aggregates'],
            "total_types": stats['total_types'],
            "by_type": {row['aggregate_type']: row['count'] for row in by_type}
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get stats: {str(e)}")

@app.get("/health")
async def health_check():
    """Мы подтверждаем что сервис работает."""
    try:
        async with db_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        return {"status": "healthy", "service": "audit-service"}
    except:
        raise HTTPException(status_code=503, detail="Database unavailable")

@app.get("/metrics")
async def metrics():
    """Мы отдаём метрики Prometheus."""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)
