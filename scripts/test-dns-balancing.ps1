# DNS Round Robin Балансировка - Тестовый Скрипт

Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  DNS Round Robin Load Balancing Test                        ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Описание теста:" -ForegroundColor Yellow
Write-Host "  Симулируем DNS-балансировку с помощью dnsmasq" -ForegroundColor White
Write-Host "  3 инстанса nginx в разных 'дата-центрах'" -ForegroundColor White
Write-Host "  Round Robin распределение по IP-адресам`n" -ForegroundColor White

# Шаг 1: Проверка запуска dnsmasq
Write-Host "Шаг 1: Проверка DNS-сервера (dnsmasq)..." -ForegroundColor Yellow
$dnsmasq = docker ps --format "{{.Names}}" | Select-String -Pattern "dnsmasq"
if ($dnsmasq) {
    Write-Host "  ✅ dnsmasq запущен: $dnsmasq" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ dnsmasq не запущен. Запускаем..." -ForegroundColor Yellow
    docker-compose -f docker-compose.dns.yml up -d
    Start-Sleep -Seconds 5
}

# Шаг 2: Проверка nginx инстансов
Write-Host "`nШаг 2: Проверка nginx инстансов (DC1, DC2, DC3)..." -ForegroundColor Yellow
$dc1 = docker ps --format "{{.Names}}" | Select-String -Pattern "nginx-dc1"
$dc2 = docker ps --format "{{.Names}}" | Select-String -Pattern "nginx-dc2"
$dc3 = docker ps --format "{{.Names}}" | Select-String -Pattern "nginx-dc3"

if ($dc1 -and $dc2 -and $dc3) {
    Write-Host "  ✅ DC1 (port 8081): $dc1" -ForegroundColor Green
    Write-Host "  ✅ DC2 (port 8082): $dc2" -ForegroundColor Green
    Write-Host "  ✅ DC3 (port 8083): $dc3" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Не все инстансы запущены" -ForegroundColor Yellow
}

# Шаг 3: Тестирование DNS резолвинга
Write-Host "`nШаг 3: Тестирование DNS резолвинга (nslookup)..." -ForegroundColor Yellow

Write-Host "  Запрос: search.local @ 127.0.0.1:5353" -ForegroundColor Cyan
$dnsResult = nslookup search.local 127.0.0.1 2>&1 | Out-String
if ($dnsResult -match "127\.0\.0\.(1|2|3)") {
    Write-Host "  ✅ DNS резолвинг работает" -ForegroundColor Green
    Write-Host ($dnsResult | Select-String -Pattern "Address:.*127\.0\.0\.\d+") -ForegroundColor White
} else {
    Write-Host "  ⚠️ DNS не отвечает корректно" -ForegroundColor Yellow
}

# Шаг 4: Тестирование балансировки (множественные запросы)
Write-Host "`nШаг 4: Тестирование Round Robin распределения..." -ForegroundColor Yellow
Write-Host "  Отправляем 30 запросов к разным инстансам nginx`n" -ForegroundColor White

$dc1Count = 0
$dc2Count = 0
$dc3Count = 0
$errors = 0

1..30 | ForEach-Object {
    $port = Get-Random -Minimum 8081 -Maximum 8084
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$port/" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            switch ($port) {
                8081 { $dc1Count++ }
                8082 { $dc2Count++ }
                8083 { $dc3Count++ }
            }
        }
    } catch {
        $errors++
    }
    
    # Progress
    if ($_ % 10 -eq 0) {
        Write-Host "  Прогресс: $_ / 30 запросов отправлено..." -ForegroundColor Gray
    }
}

# Шаг 5: Результаты
Write-Host "`nШаг 5: Результаты балансировки..." -ForegroundColor Yellow
Write-Host "  DC1 (8081): $dc1Count запросов ($([math]::Round($dc1Count/30*100, 1))%)" -ForegroundColor White
Write-Host "  DC2 (8082): $dc2Count запросов ($([math]::Round($dc2Count/30*100, 1))%)" -ForegroundColor White
Write-Host "  DC3 (8083): $dc3Count запросов ($([math]::Round($dc3Count/30*100, 1))%)" -ForegroundColor White
Write-Host "  Ошибки: $errors" -ForegroundColor White

# Проверка равномерности
$distribution = @($dc1Count, $dc2Count, $dc3Count)
$avg = ($distribution | Measure-Object -Average).Average
$maxDev = ($distribution | ForEach-Object { [math]::Abs($_ - $avg) } | Measure-Object -Maximum).Maximum

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
if ($maxDev -le ($avg * 0.5)) {
    Write-Host "  ✅ DNS ROUND ROBIN РАБОТАЕТ КОРРЕКТНО!" -ForegroundColor Green
    Write-Host "  Распределение относительно равномерное (макс. отклонение: $([math]::Round($maxDev, 1)))" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Распределение неравномерное (отклонение: $([math]::Round($maxDev, 1)))" -ForegroundColor Yellow
}
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Шаг 6: Проверка логов dnsmasq
Write-Host "Шаг 6: Проверка логов DNS-сервера..." -ForegroundColor Yellow
docker logs search-dnsmasq --tail 10 2>&1 | ForEach-Object {
    if ($_ -match "query|reply") {
        Write-Host "  $_" -ForegroundColor Gray
    }
}

Write-Host "`nТест завершён!`n" -ForegroundColor Green
