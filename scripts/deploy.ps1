# Скрипт для полного развертывания системы
# ЛР4: Высоконагруженные системы

param(
    [switch]$Clean,
    [switch]$Build,
    [switch]$NoPull
)

$ErrorActionPreference = "Stop"

Write-Host "=== Deploying Search System (LR4) ===" -ForegroundColor Cyan
Write-Host ""

# Функция для вывода статуса
function Write-Status {
    param([string]$Message, [string]$Color = "Yellow")
    Write-Host "► $Message" -ForegroundColor $Color
}

# Проверка Docker
Write-Status "Checking Docker..." "Yellow"
try {
    docker --version | Out-Null
    Write-Host "  ✓ Docker is installed" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Docker is not installed or not running" -ForegroundColor Red
    exit 1
}

try {
    docker-compose --version | Out-Null
    Write-Host "  ✓ Docker Compose is installed" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Docker Compose is not installed" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Очистка (если требуется)
if ($Clean) {
    Write-Status "Cleaning up..." "Yellow"
    docker-compose down -v
    docker volume prune -f
    Write-Host "  ✓ Cleanup complete" -ForegroundColor Green
    Write-Host ""
}

# Pull images (если не отключено)
if (-not $NoPull) {
    Write-Status "Pulling Docker images..." "Yellow"
    docker-compose pull
    Write-Host "  ✓ Images pulled" -ForegroundColor Green
    Write-Host ""
}

# Build (если требуется)
if ($Build) {
    Write-Status "Building services..." "Yellow"
    docker-compose build --no-cache
    Write-Host "  ✓ Build complete" -ForegroundColor Green
    Write-Host ""
}

# Запуск системы
Write-Status "Starting services..." "Yellow"
docker-compose up -d
Write-Host "  ✓ Services started" -ForegroundColor Green
Write-Host ""

# Ожидание готовности
Write-Status "Waiting for services to be healthy (this may take 1-2 minutes)..." "Yellow"
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
    Write-Progress -Activity "Waiting for services" -Status "$healthyCount/$totalCount healthy" -PercentComplete $progress
    
    if ($healthyCount -eq $totalCount) {
        $allHealthy = $true
    }
}

Write-Progress -Activity "Waiting for services" -Completed

if ($allHealthy) {
    Write-Host "  ✓ All services are healthy" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Some services may not be healthy yet" -ForegroundColor Yellow
}
Write-Host ""

# Проверка доступности
Write-Status "Checking service availability..." "Yellow"

$endpoints = @(
    @{Name="Frontend"; URL="http://localhost/"},
    @{Name="Search API"; URL="http://localhost/api/search?q=test"},
    @{Name="Prometheus"; URL="http://localhost:9090/-/healthy"},
    @{Name="Grafana"; URL="http://localhost:3000/api/health"},
    @{Name="RabbitMQ"; URL="http://localhost:15672/"}
)

foreach ($endpoint in $endpoints) {
    try {
        $response = Invoke-WebRequest -Uri $endpoint.URL -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Host "  ✓ $($endpoint.Name): Available" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ $($endpoint.Name): Not available" -ForegroundColor Red
    }
}
Write-Host ""

# Вывод информации
Write-Host "=== Deployment Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Access the following services:" -ForegroundColor Yellow
Write-Host "  • Frontend:            http://localhost" -ForegroundColor Cyan
Write-Host "  • Grafana:             http://localhost:3000 (admin/admin)" -ForegroundColor Cyan
Write-Host "  • Prometheus:          http://localhost:9090" -ForegroundColor Cyan
Write-Host "  • RabbitMQ Management: http://localhost:15672 (admin/admin)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Yellow
Write-Host "  • View logs:           docker-compose logs -f" -ForegroundColor Cyan
Write-Host "  • Check status:        docker-compose ps" -ForegroundColor Cyan
Write-Host "  • Stop system:         docker-compose down" -ForegroundColor Cyan
Write-Host "  • Test failover:       .\scripts\test-failover.ps1" -ForegroundColor Cyan
Write-Host "  • Load test:           python .\scripts\load-test.py --requests 10000" -ForegroundColor Cyan
Write-Host ""

# Показать статус контейнеров
Write-Status "Container Status:" "Yellow"
docker-compose ps
Write-Host ""

Write-Host "✓ System is ready for testing!" -ForegroundColor Green
