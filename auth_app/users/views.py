from django.shortcuts import render
from django.http import JsonResponse
from django.db import connection


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
