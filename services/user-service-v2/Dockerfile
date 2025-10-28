FROM python:3.11-slim

WORKDIR /app

# Мы ставим зависимости
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Мы копируем приложение
COPY . .

# Мы открываем порт
EXPOSE 8000

# Мы добавляем healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

# Мы запускаем сервис
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
