# Высоконагруженные системы

## Лабораторная работа №1: Освоение Docker и Docker Compose

**ФИО:** Скрыпник Василий Александрович  
**Вариант:** 2 - Веб-приложение с аутентификацией

### Описание задания
Веб-сервис с регистрацией и входом пользователей.

**Требования:**
- Используются Django и django-allauth
- Настроены страницы /login, /register, /dashboard
- Данные пользователей сохраняются в PostgreSQL
- Дополнительно: добавлен Docker-образ для Nginx как фронтенд

### Запуск проекта
```bash
cd auth_app
docker-compose up --build
```

Или на Windows:
```
cd auth_app
.\start.bat
```

### Доступные URL
- Главная страница: http://localhost
- Вход: http://localhost/login/
- Регистрация: http://localhost/register/
- Личный кабинет (после авторизации): http://localhost/dashboard/
- Проверка здоровья API: http://localhost/health/

### Используемые технологии
- Docker и Docker Compose
- Python/Django/django-allauth
- PostgreSQL
- Nginx (фронтенд)
- Gunicorn (WSGI-сервер)