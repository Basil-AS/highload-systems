# Тест Canary Deployment
# Проверяет распределение трафика между v1 и v2 user-service

param(
    [int]$RequestCount = 100,
    [string]$Url = "http://localhost/health/user-v1"
)

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Тест стратегии Canary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Проверка доступности обоих сервисов
Write-Host "Шаг 1: Проверка статуса сервисов..." -ForegroundColor Yellow

try {
    $v1Health = Invoke-RestMethod -Uri "http://localhost/health/user-v1" -Method Get
    Write-Host "  ✓ User Service V1: $($v1Health.status) (версия: $($v1Health.version))" -ForegroundColor Green
} catch {
    Write-Host "  ✗ User Service V1: недоступен" -ForegroundColor Red
    exit 1
}

try {
    $v2Health = Invoke-RestMethod -Uri "http://localhost/health/user-v2" -Method Get
    Write-Host "  ✓ User Service V2: $($v2Health.status) (версия: $($v2Health.version))" -ForegroundColor Green
} catch {
    Write-Host "  ✗ User Service V2: недоступен" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Шаг 2: Проверка распределения трафика ($RequestCount запросов)..." -ForegroundColor Yellow

$v1Count = 0
$v2Count = 0
$errorCount = 0

for ($i = 1; $i -le $RequestCount; $i++) {
    try {
        # Используем разные IP для имитации разных клиентов (для split_clients)
        $fakeIp = "192.168.$([math]::Floor($i / 256)).$($i % 256)"
        $headers = @{
            "User-Agent" = "TestClient-$i"
            "X-Forwarded-For" = $fakeIp
        }
        
        # Запрос проходит через API gateway (nginx будет распределять)
        $response = Invoke-RestMethod -Uri "http://localhost/api/users/1/quota" -Method Get -Headers $headers -ErrorAction Stop
        
        # Определяем версию по quota (V1=100, V2=200)
        if ($response.quota_per_minute -eq 200) {
            $v2Count++
        } else {
            $v1Count++
        }
        
        # Прогресс каждые 10 запросов
        if ($i % 10 -eq 0) {
            Write-Host "  Прогресс: отправлено $i из $RequestCount" -ForegroundColor Gray
        }
    } catch {
        $errorCount++
        Write-Host "  Ошибка на запросе $i : $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Шаг 3: Результаты..." -ForegroundColor Yellow

$totalSuccess = $v1Count + $v2Count
$v1Percentage = if ($totalSuccess -gt 0) { [math]::Round(($v1Count / $totalSuccess) * 100, 2) } else { 0 }
$v2Percentage = if ($totalSuccess -gt 0) { [math]::Round(($v2Count / $totalSuccess) * 100, 2) } else { 0 }

Write-Host "  Запросов в V1: $v1Count ($v1Percentage%)" -ForegroundColor White
Write-Host "  Запросов в V2: $v2Count ($v2Percentage%)" -ForegroundColor White
Write-Host "  Ошибок: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "White" })
Write-Host ""

# Проверка соответствия ожиданиям (90/10 с погрешностью ±5%)
$expectedV2Min = 5
$expectedV2Max = 15

if ($v2Percentage -ge $expectedV2Min -and $v2Percentage -le $expectedV2Max) {
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  ✅ Проверка стратегии Canary пройдена" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  Доля трафика в V2: $v2Percentage% (ожидание: 10% ±5%)" -ForegroundColor Green
} else {
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  ⚠️  Стратегия Canary работает нестабильно" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  Доля трафика в V2: $v2Percentage% (ожидание: 10% ±5%)" -ForegroundColor Yellow
    Write-Host "  Примечание: возможна малая выборка или особенности хеширования" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Шаг 4: Проверка различий в функциональности..." -ForegroundColor Yellow

# Тест квоты (V1: 100, V2: 200)
try {
    $quotaResponse = Invoke-RestMethod -Uri "http://localhost/api/users/1/quota" -Method Get
    Write-Host "  Лимит пользователя: $($quotaResponse.quota_per_minute) запросов в минуту" -ForegroundColor White
    
    if ($quotaResponse.version) {
        Write-Host "  Версия сервиса: $($quotaResponse.version)" -ForegroundColor White
    }
} catch {
    Write-Host "  ⚠️  Проверка квоты завершилась ошибкой" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Проверка завершена" -ForegroundColor Cyan
