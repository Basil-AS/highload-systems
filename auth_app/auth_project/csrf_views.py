from django.shortcuts import render
from django.middleware.csrf import get_token

def csrf_failure(request, reason=""):
    """
    Обработчик ошибок CSRF
    """
    # Получаем новый CSRF-токен
    csrf_token = get_token(request)
    
    # Контекст с информацией об ошибке
    context = {
        'reason': reason,
        'csrf_token': csrf_token,
    }
    
    response = render(request, 'csrf_error.html', context)
    # Устанавливаем статус 403 Forbidden
    response.status_code = 403
    return response
