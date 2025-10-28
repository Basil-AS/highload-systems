"""
Сервис пользователей. Мы держим API для регистрации и входа.
"""
import os
import asyncio
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Depends, Header
from pydantic import BaseModel, EmailStr, Field
from passlib.context import CryptContext
from jose import jwt, JWTError
import asyncpg
import httpx
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response

# Мы задаём настройки
SERVICE_VERSION = "2.0.0"  # новая версия 2.0
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://docker:secret@localhost:5432/users_db")
AUDIT_SERVICE_URL = os.getenv("AUDIT_SERVICE_URL", "http://audit-service:8000")
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Мы настраиваем хеширование паролей
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Мы объявляем метрики Prometheus
REQUEST_COUNT = Counter('user_service_requests_total', 'Total requests', ['method', 'endpoint', 'status', 'version'])
REQUEST_LATENCY = Histogram('user_service_request_duration_seconds', 'Request latency', ['method', 'endpoint', 'version'])

# Мы держим пул соединений с базой
db_pool: Optional[asyncpg.Pool] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Мы поднимаем пул при старте и закрываем его."""
    global db_pool
    db_pool = await asyncpg.create_pool(DATABASE_URL, min_size=2, max_size=10)
    
    # Мы создаём таблицы если их нет
    async with db_pool.acquire() as conn:
        await conn.execute("""
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
        """)
    
    yield
    
    await db_pool.close()

# Мы создаём приложение FastAPI
app = FastAPI(
    title="User Service V2",
    description=f"🆕 Управление пользователями поисковой системы V2 (ЛР4, Вариант 8) - Version {SERVICE_VERSION}",
    version=SERVICE_VERSION,
    lifespan=lifespan
)

# Мы описываем модели запросов и ответов
class UserRegister(BaseModel):
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6)
    full_name: Optional[str] = None

class UserLogin(BaseModel):
    username: str
    password: str

class UserResponse(BaseModel):
    id: int
    email: str
    username: str
    full_name: Optional[str]
    is_active: bool
    created_at: datetime
    version: str = SERVICE_VERSION  # Мы отправляем номер релиза

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    version: str = SERVICE_VERSION  # Мы добавляем релиз в токен

# Мы описываем вспомогательные функции
def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=15))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user_id(authorization: Optional[str] = Header(None)) -> int:
    """Мы достаём id пользователя из JWT."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid authorization header")
    
    token = authorization.split(" ")[1]
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id_str: str = payload.get("sub")
        if user_id_str is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return int(user_id_str)
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

async def publish_audit_event(event_type: str, aggregate_id: int, event_data: Dict[str, Any], user_id: Optional[int] = None):
    """Мы отправляем событие в аудит."""
    try:
        async with httpx.AsyncClient() as client:
            await client.post(
                f"{AUDIT_SERVICE_URL}/events",
                json={
                    "aggregate_type": "user",
                    "aggregate_id": str(aggregate_id),
                    "event_type": event_type,
                    "event_data": {**event_data, "service_version": SERVICE_VERSION},  # 🆕 Версия в событиях
                    "user_id": str(user_id) if user_id else None
                },
                timeout=2.0
            )
    except Exception as e:
        # Мы просто логируем если аудит недоступен
        print(f"Failed to publish audit event: {e}")

# Мы описываем HTTP-эндпоинты
@app.get("/health")
async def health_check():
    """Мы отвечаем что сервис жив."""
    try:
        async with db_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        return {
            "status": "healthy",
            "service": "user-service",
            "version": SERVICE_VERSION  # 🆕 Версия в health check
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database connection failed: {str(e)}")

@app.get("/metrics")
async def metrics():
    """Мы отдаём метрики Prometheus."""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.post("/api/users/register", response_model=UserResponse, status_code=201)
async def register_user(user: UserRegister):
    """Мы регистрируем пользователя."""
    with REQUEST_LATENCY.labels(method="POST", endpoint="/api/users/register", version=SERVICE_VERSION).time():
        try:
            hashed_password = get_password_hash(user.password)
            
            async with db_pool.acquire() as conn:
                row = await conn.fetchrow(
                    """
                    INSERT INTO users (email, username, hashed_password, full_name)
                    VALUES ($1, $2, $3, $4)
                    RETURNING id, email, username, full_name, is_active, created_at
                    """,
                    user.email, user.username, hashed_password, user.full_name
                )
            
            user_response = UserResponse(**dict(row))
            
            # Мы шлём событие в аудит в фоне
            asyncio.create_task(publish_audit_event(
                "created",
                user_response.id,
                {"email": user.email, "username": user.username, "full_name": user.full_name},
                user_response.id
            ))
            
            REQUEST_COUNT.labels(method="POST", endpoint="/api/users/register", status="success", version=SERVICE_VERSION).inc()
            return user_response
            
        except asyncpg.UniqueViolationError:
            REQUEST_COUNT.labels(method="POST", endpoint="/api/users/register", status="error", version=SERVICE_VERSION).inc()
            raise HTTPException(status_code=400, detail="Email or username already exists")
        except Exception as e:
            REQUEST_COUNT.labels(method="POST", endpoint="/api/users/register", status="error", version=SERVICE_VERSION).inc()
            raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")

@app.post("/api/users/login", response_model=Token)
async def login_user(credentials: UserLogin):
    """Мы выдаём токен по логину."""
    with REQUEST_LATENCY.labels(method="POST", endpoint="/api/users/login", version=SERVICE_VERSION).time():
        async with db_pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT id, username, hashed_password, is_active FROM users WHERE username = $1",
                credentials.username
            )
        
        if not row:
            REQUEST_COUNT.labels(method="POST", endpoint="/api/users/login", status="error", version=SERVICE_VERSION).inc()
            raise HTTPException(status_code=401, detail="Invalid username or password")
        
        if not row["is_active"]:
            REQUEST_COUNT.labels(method="POST", endpoint="/api/users/login", status="error", version=SERVICE_VERSION).inc()
            raise HTTPException(status_code=403, detail="User account is disabled")
        
        if not verify_password(credentials.password, row["hashed_password"]):
            REQUEST_COUNT.labels(method="POST", endpoint="/api/users/login", status="error").inc()
            raise HTTPException(status_code=401, detail="Invalid username or password")
        
        access_token = create_access_token(
            data={"sub": str(row["id"]), "username": row["username"]},
            expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        )
        
        REQUEST_COUNT.labels(method="POST", endpoint="/api/users/login", status="success", version=SERVICE_VERSION).inc()
        return Token(access_token=access_token)

@app.get("/api/users/profile", response_model=UserResponse)
async def get_profile(user_id: int = Depends(get_current_user_id)):
    """Мы показываем профиль текущего пользователя."""
    with REQUEST_LATENCY.labels(method="GET", endpoint="/api/users/profile", version=SERVICE_VERSION).time():
        async with db_pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT id, email, username, full_name, is_active, created_at FROM users WHERE id = $1",
                user_id
            )
        
        if not row:
            REQUEST_COUNT.labels(method="GET", endpoint="/api/users/profile", status="error", version=SERVICE_VERSION).inc()
            raise HTTPException(status_code=404, detail="User not found")
        
        REQUEST_COUNT.labels(method="GET", endpoint="/api/users/profile", status="success", version=SERVICE_VERSION).inc()
        return UserResponse(**dict(row))

@app.get("/api/users/{user_id}/quota")
async def get_user_quota(user_id: int):
    """Мы сообщаем квоту для других сервисов."""
    # Мы держим лимит 200 запросов в минуту
    return {
        "user_id": user_id,
        "quota_per_minute": 200,  # Было 100, стало 200
        "exceeded": False,
        "version": SERVICE_VERSION
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
