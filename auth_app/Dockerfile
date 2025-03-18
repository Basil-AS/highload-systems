FROM python:3.13-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Установка curl для проверки здоровья
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Добавляем права на выполнение для entrypoint скрипта
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

# Используем entrypoint скрипт для инициализации
ENTRYPOINT ["/bin/bash", "/app/entrypoint.sh"]
