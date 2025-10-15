from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.db import connection
import os
import random


def health_check(request):
    """
    Проверка здоровья API и доступности базы данных
    """
    health_status = {
        'status': 'ok',
        'database': 'unavailable',
        'variant': 2,
    }
    
    # Проверяем подключение к базе данных
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1')
            if cursor.fetchone():
                health_status['database'] = 'available'
    except Exception as e:
        health_status['status'] = 'error'
        health_status['error'] = str(e)
    
    return JsonResponse(health_status)


def status_view(request):
    """Возвращает информацию о сервисе и порту (для проверки балансировки)."""
    port = os.getenv("PORT", "8000")
    return JsonResponse({
        "service": "backend",
        "port": int(port)
    })


@csrf_exempt
def data_view(request):
    """Возвращает случайные данные (для проверки кэширования)."""
    return JsonResponse({
        "value": random.randint(1, 100)
    })


def error_view(request):
    """Страница, возвращающая код ответа отличный от 200 (для варианта 2)."""
    return JsonResponse({"error": "intentional error"}, status=418)
