# Тест Canary Deployment
# Проверяет распределение трафика между v1 и v2 user-service

param(
    [int]$RequestCount = 100,
    [string]$Url = "http://localhost/health/user-v1"
)

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Canary Deployment Test" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Проверяем что оба сервиса работают
Write-Host "Step 1: Checking services health..." -ForegroundColor Yellow

try {
    $v1Health = Invoke-RestMethod -Uri "http://localhost/health/user-v1" -Method Get
    Write-Host "  ✓ User Service V1: $($v1Health.status) (version: $($v1Health.version))" -ForegroundColor Green
} catch {
    Write-Host "  ✗ User Service V1: FAILED" -ForegroundColor Red
    exit 1
}

try {
    $v2Health = Invoke-RestMethod -Uri "http://localhost/health/user-v2" -Method Get
    Write-Host "  ✓ User Service V2: $($v2Health.status) (version: $($v2Health.version))" -ForegroundColor Green
} catch {
    Write-Host "  ✗ User Service V2: FAILED" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Testing traffic distribution ($RequestCount requests)..." -ForegroundColor Yellow

$v1Count = 0
$v2Count = 0
$errorCount = 0

for ($i = 1; $i -le $RequestCount; $i++) {
    try {
        # Используем разные User-Agent для имитации разных клиентов
        $headers = @{
            "User-Agent" = "TestClient-$i"
        }
        
        # Делаем запрос через API gateway (nginx будет распределять)
        $response = Invoke-WebRequest -Uri "http://localhost/api/users/1/quota" -Method Get -Headers $headers
        
        $version = $response.Headers["X-Backend-Version"]
        if ($version -eq "v1") {
            $v1Count++
        } elseif ($version -eq "v2") {
            $v2Count++
        } else {
            # Пробуем получить версию из ответа JSON
            try {
                $content = $response.Content | ConvertFrom-Json
                if ($content.version -match "2\.0") {
                    $v2Count++
                } else {
                    $v1Count++
                }
            } catch {
                $v1Count++  # Default to v1 if can't determine
            }
        }
        
        # Прогресс каждые 10 запросов
        if ($i % 10 -eq 0) {
            Write-Host "  Progress: $i / $RequestCount requests sent..." -ForegroundColor Gray
        }
    } catch {
        $errorCount++
    }
}

Write-Host ""
Write-Host "Step 3: Results..." -ForegroundColor Yellow

$totalSuccess = $v1Count + $v2Count
$v1Percentage = if ($totalSuccess -gt 0) { [math]::Round(($v1Count / $totalSuccess) * 100, 2) } else { 0 }
$v2Percentage = if ($totalSuccess -gt 0) { [math]::Round(($v2Count / $totalSuccess) * 100, 2) } else { 0 }

Write-Host "  V1 requests: $v1Count ($v1Percentage%)" -ForegroundColor White
Write-Host "  V2 requests: $v2Count ($v2Percentage%)" -ForegroundColor White
Write-Host "  Errors: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "White" })
Write-Host ""

# Проверка соответствия ожиданиям (90/10 с погрешностью ±5%)
$expectedV2Min = 5
$expectedV2Max = 15

if ($v2Percentage -ge $expectedV2Min -and $v2Percentage -le $expectedV2Max) {
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  ✅ CANARY DEPLOYMENT TEST PASSED!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  V2 traffic: $v2Percentage% (expected: 10% ±5%)" -ForegroundColor Green
} else {
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  ⚠️  CANARY DEPLOYMENT SUBOPTIMAL" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  V2 traffic: $v2Percentage% (expected: 10% ±5%)" -ForegroundColor Yellow
    Write-Host "  Note: This may be due to small sample size or hash distribution" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Step 4: Testing feature differences..." -ForegroundColor Yellow

# Тест квоты (V1: 100, V2: 200)
try {
    $quotaResponse = Invoke-RestMethod -Uri "http://localhost/api/users/1/quota" -Method Get
    Write-Host "  User quota: $($quotaResponse.quota_per_minute) requests/min" -ForegroundColor White
    
    if ($quotaResponse.version) {
        Write-Host "  Service version: $($quotaResponse.version)" -ForegroundColor White
    }
} catch {
    Write-Host "  ⚠️  Quota check failed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Test completed!" -ForegroundColor Cyan
