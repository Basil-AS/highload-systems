#!/usr/bin/env pwsh
# Скрипт для быстрого заполнения системы демо-данными

Write-Host "🚀 Заполнение системы демонстрационными данными..." -ForegroundColor Cyan

$baseUrl = "http://localhost"

# Список демо-документов
$documents = @(
    @{
        title = "Введение в высоконагруженные системы"
        content = "Высоконагруженные системы - это системы, которые должны обрабатывать большое количество запросов в единицу времени. Основные принципы: масштабируемость, отказоустойчивость, производительность."
        author = "Василий Скрыпник"
    },
    @{
        title = "PostgreSQL и репликация"
        content = "PostgreSQL поддерживает различные методы репликации: потоковая репликация, логическая репликация, pg_auto_failover для автоматического переключения при отказе."
        author = "Database Expert"
    },
    @{
        title = "RabbitMQ и очереди сообщений"
        content = "RabbitMQ - это брокер сообщений, который реализует протокол AMQP. Используется для асинхронной обработки задач, event sourcing и межсервисного взаимодействия."
        author = "Message Queue Specialist"
    },
    @{
        title = "Nginx как API Gateway"
        content = "Nginx может выступать в роли API Gateway, обеспечивая load balancing, rate limiting, кеширование и SSL termination. Поддерживает Canary Deployment через split_clients."
        author = "DevOps Engineer"
    },
    @{
        title = "Prometheus и мониторинг метрик"
        content = "Prometheus - это система мониторинга с временными рядами. Собирает метрики по модели pull, поддерживает PromQL для запросов и AlertManager для уведомлений."
        author = "SRE Specialist"
    },
    @{
        title = "Grafana визуализация данных"
        content = "Grafana - платформа для визуализации метрик из различных источников: Prometheus, InfluxDB, Elasticsearch. Поддерживает создание интерактивных дашбордов."
        author = "Monitoring Team"
    },
    @{
        title = "Canary Deployment стратегия"
        content = "Canary Deployment позволяет постепенно раскатывать новую версию сервиса, направляя на неё небольшой процент трафика (например 20%). Это снижает риски при развертывании."
        author = "Release Manager"
    },
    @{
        title = "Event Sourcing архитектурный паттерн"
        content = "Event Sourcing - это подход, при котором состояние системы определяется последовательностью событий. Все изменения сохраняются как события, что обеспечивает полный audit trail."
        author = "Software Architect"
    },
    @{
        title = "DNS Round Robin балансировка"
        content = "DNS Round Robin - простой метод балансировки нагрузки на уровне DNS. Сервер возвращает список IP-адресов в циклическом порядке, распределяя трафик между серверами."
        author = "Network Engineer"
    },
    @{
        title = "Партицирование в PostgreSQL"
        content = "Партицирование (Partitioning) - это разделение больших таблиц на меньшие физические части. Улучшает производительность запросов и упрощает управление данными."
        author = "Database Administrator"
    },
    @{
        title = "Валидация данных в FastAPI"
        content = "FastAPI использует Pydantic для автоматической валидации данных. Это обеспечивает type safety, автоматическую генерацию OpenAPI схем и понятные сообщения об ошибках."
        author = "Backend Developer"
    },
    @{
        title = "Асинхронное программирование в Python"
        content = "AsyncIO в Python позволяет писать конкурентный код с помощью async/await. Это особенно эффективно для I/O-bound операций, таких как работа с базой данных и HTTP запросы."
        author = "Python Developer"
    },
    @{
        title = "Docker и контейнеризация"
        content = "Docker позволяет упаковывать приложения в контейнеры, обеспечивая изолированное окружение и воспроизводимость. Docker Compose упрощает управление multi-container приложениями."
        author = "DevOps Team"
    },
    @{
        title = "Rate Limiting защита от перегрузки"
        content = "Rate Limiting ограничивает количество запросов от клиента за единицу времени. Nginx реализует это через ngx_http_limit_req_module, защищая backend от DDoS атак."
        author = "Security Engineer"
    },
    @{
        title = "Кеширование в высоконагруженных системах"
        content = "Кеширование - ключевая техника оптимизации. Nginx может кешировать ответы API, Redis/Valkey используется для сессий, а PostgreSQL имеет встроенный кеш запросов."
        author = "Performance Engineer"
    }
)

Write-Host "`n📝 Создание $($documents.Count) документов..." -ForegroundColor Yellow

$created = 0
$failed = 0

foreach ($doc in $documents) {
    try {
        $body = $doc | ConvertTo-Json -Depth 3
        $response = Invoke-RestMethod -Uri "$baseUrl/api/documents" `
            -Method Post `
            -ContentType "application/json" `
            -Body $body `
            -ErrorAction Stop
        
        Write-Host "✓ Создан: $($doc.title)" -ForegroundColor Green
        $created++
        Start-Sleep -Milliseconds 200
    }
    catch {
        Write-Host "✗ Ошибка: $($doc.title) - $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`n📊 Результаты:" -ForegroundColor Cyan
Write-Host "  ✓ Успешно создано: $created документов" -ForegroundColor Green
Write-Host "  ✗ Ошибок: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Gray" })

# Проверка созданных документов
Write-Host "`n🔍 Проверка созданных документов..." -ForegroundColor Cyan
try {
    $docs = Invoke-RestMethod -Uri "$baseUrl/api/documents?limit=100"
    Write-Host "  📄 Всего документов в системе: $($docs.Count)" -ForegroundColor Green
    
    # Проверка индексации
    $indexed = ($docs | Where-Object { $_.indexed -eq $true }).Count
    $pending = ($docs | Where-Object { $_.indexed -eq $false }).Count
    Write-Host "  ✓ Проиндексировано: $indexed" -ForegroundColor Green
    Write-Host "  ⏳ Ожидает индексации: $pending" -ForegroundColor Yellow
}
catch {
    Write-Host "  ✗ Ошибка получения списка документов" -ForegroundColor Red
}

Write-Host "`n✅ Готово! Система заполнена демо-данными." -ForegroundColor Green
Write-Host "💡 Откройте http://localhost и нажмите 'Обновить список' в разделе документов." -ForegroundColor Cyan
