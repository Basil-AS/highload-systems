@echo off
chcp 65001 > nul
echo Проверка установленной версии Docker и Docker Compose
echo ---------------------------------------------------
echo.

echo Проверка Docker:
docker --version
IF %ERRORLEVEL% NEQ 0 (
    echo [ОШИБКА] Docker не установлен или не запущен.
    echo Для Windows: Установите Docker Desktop с https://www.docker.com/products/docker-desktop
    goto end
)

echo.
echo Проверка Docker Compose:
docker-compose --version
IF %ERRORLEVEL% NEQ 0 (
    echo [ОШИБКА] Docker Compose не установлен.
    echo Docker Compose обычно устанавливается вместе с Docker Desktop для Windows.
    goto end
)

echo.
echo [УСПЕХ] Docker и Docker Compose установлены и готовы к использованию.
echo.
echo Для запуска проекта выполните:
echo cd auth_app
echo docker-compose up --build
echo.
echo Или просто запустите start.bat в папке auth_app

:end
pause
