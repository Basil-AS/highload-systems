# Скрипт для полного развертывания системы
# ЛР4: Высоконагруженные системы

param(
    [switch]$Clean,
    [switch]$Build,
    [switch]$NoPull
)

$ErrorActionPreference = "Stop"

Write-Host "=== Развертывание поисковой системы (ЛР4) ===" -ForegroundColor Cyan
Write-Host ""

# Вспомогательная функция для вывода статуса
function Write-Status {
    param([string]$Message, [string]$Color = "Yellow")
    Write-Host "► $Message" -ForegroundColor $Color
}

# Проверка Docker
Write-Status "Проверка Docker..." "Yellow"
try {
    docker --version | Out-Null
    Write-Host "  ✓ Docker установлен" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Docker не установлен или не запущен" -ForegroundColor Red
    exit 1
}

try {
    docker-compose --version | Out-Null
    Write-Host "  ✓ Docker Compose установлен" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Docker Compose не установлен" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Очистка окружения при необходимости
if ($Clean) {
    Write-Status "Очистка окружения..." "Yellow"
    docker-compose down -v
    docker volume prune -f
    Write-Host "  ✓ Очистка завершена" -ForegroundColor Green
    Write-Host ""
}

# Загрузка образов при необходимости
if (-not $NoPull) {
    Write-Status "Загрузка образов Docker..." "Yellow"
    docker-compose pull
    Write-Host "  ✓ Образы загружены" -ForegroundColor Green
    Write-Host ""
}

# Сборка образов при необходимости
if ($Build) {
    Write-Status "Сборка сервисов..." "Yellow"
    docker-compose build --no-cache
    Write-Host "  ✓ Сборка завершена" -ForegroundColor Green
    Write-Host ""
}

# Запуск сервисов
Write-Status "Запуск сервисов..." "Yellow"
docker-compose up -d
Write-Host "  ✓ Сервисы запущены" -ForegroundColor Green
Write-Host ""

# Ожидание статуса healthy
Write-Status "Ожидание готовности сервисов (до 1-2 минут)..." "Yellow"
$maxAttempts = 60
$attempt = 0
$allHealthy = $false

while ($attempt -lt $maxAttempts -and -not $allHealthy) {
    $attempt++
    Start-Sleep -Seconds 2
    
    $services = docker-compose ps --format json | ConvertFrom-Json
    $healthyCount = 0
    $totalCount = 0
    
    foreach ($service in $services) {
        $totalCount++
        if ($service.Health -eq "healthy" -or $service.State -eq "running") {
            $healthyCount++
        }
    }
    
    $progress = [math]::Round(($healthyCount / $totalCount) * 100)
    Write-Progress -Activity "Ожидание готовности сервисов" -Status "$healthyCount/$totalCount готово" -PercentComplete $progress
    
    if ($healthyCount -eq $totalCount) {
        $allHealthy = $true
    }
}

Write-Progress -Activity "Ожидание готовности сервисов" -Completed

if ($allHealthy) {
    Write-Host "  ✓ Все сервисы готовы" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Не все сервисы успели перейти в healthy" -ForegroundColor Yellow
}
Write-Host ""

# Проверка доступности сервисов
Write-Status "Проверка доступности сервисов..." "Yellow"

$endpoints = @(
    @{Name="Фронтенд"; URL="http://localhost/"},
    @{Name="Поисковый API"; URL="http://localhost/api/search?q=test"},
    @{Name="Prometheus"; URL="http://localhost:9090/-/healthy"},
    @{Name="Grafana"; URL="http://localhost:3000/api/health"},
    @{Name="RabbitMQ"; URL="http://localhost:15672/"}
)

foreach ($endpoint in $endpoints) {
    try {
        Invoke-WebRequest -Uri $endpoint.URL -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop | Out-Null
        Write-Host "  ✓ $($endpoint.Name): доступен" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ $($endpoint.Name): недоступен" -ForegroundColor Red
    }
}
Write-Host ""

# Вывод итоговой информации
Write-Host "=== Развертывание завершено ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Доступны сервисы:" -ForegroundColor Yellow
Write-Host "  • Фронтенд:            http://localhost" -ForegroundColor Cyan
Write-Host "  • Grafana:             http://localhost:3000 (admin/admin)" -ForegroundColor Cyan
Write-Host "  • Prometheus:          http://localhost:9090" -ForegroundColor Cyan
Write-Host "  • RabbitMQ Management: http://localhost:15672 (admin/admin)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Полезные команды:" -ForegroundColor Yellow
Write-Host "  • Просмотр логов:      docker-compose logs -f" -ForegroundColor Cyan
Write-Host "  • Проверка статуса:    docker-compose ps" -ForegroundColor Cyan
Write-Host "  • Остановка системы:   docker-compose down" -ForegroundColor Cyan
Write-Host "  • Тест отказоустойчивости: .\scripts\test-failover.ps1" -ForegroundColor Cyan
Write-Host "  • Нагрузочное тестирование: python .\scripts\load-test.py --requests 10000" -ForegroundColor Cyan
Write-Host ""

# Вывод статуса контейнеров
Write-Status "Состояние контейнеров:" "Yellow"
docker-compose ps
Write-Host ""

Write-Host "✓ Система готова к тестированию" -ForegroundColor Green
