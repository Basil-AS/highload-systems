# Веб-приложение с аутентификацией

Проект для ЛР №1 и продолжение для ЛР №2 по предмету "Высоконагруженные системы".

## Скрыпник Василий Александрович 211-331

**Вариант:** 2

## Описание проекта

Веб-сервис с регистрацией и входом пользователей.

### Требования:
- Используются Django и django-allauth
- Настроены страницы /login, /register, /dashboard
- Данные пользователей сохраняются в PostgreSQL
- Дополнительно: добавлен Docker-образ для Nginx как фронтенд

### Доступные страницы
- Главная страница: http://localhost
- Вход: http://localhost/login/
- Регистрация: http://localhost/register/
- Личный кабинет (после авторизации): http://localhost/dashboard/
- Проверка здоровья API: http://localhost/health/
- Административная панель: http://localhost/admin/ (логин: admin, пароль: admin123)

## Запуск ЛР2 (балансировка и кэширование)
- Конфигурация docker-compose с 3 бэкендами: `docker-compose.yml.new`
- Nginx конфигурация: `nginx/nginx.conf` (upstream, кэш, rate limiting, gzip)

Команды (PowerShell):
1) Собрать и запустить:
	docker compose -f docker-compose.yml.new up --build
2) Проверка балансировки:
	Вызвать 10+ раз: http://localhost/status
3) Проверка кэша:
	Вызвать несколько раз: http://localhost/data и смотреть заголовок X-Cache-Status
