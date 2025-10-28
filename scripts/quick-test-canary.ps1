# Быстрый тест Canary Deployment (10 запросов)
Write-Host "🧪 Быстрый тест Canary (10 запросов)`n" -ForegroundColor Cyan

$v1 = 0
$v2 = 0

1..10 | ForEach-Object {
    $response = curl -s -H "User-Agent: Test-$_" http://localhost/api/users/1/quota | ConvertFrom-Json
    if ($response.quota_per_minute -eq 200) { $v2++ } else { $v1++ }
}

$v2Pct = [math]::Round(($v2 / 10) * 100, 1)

Write-Host "✅ V1: $v1 запросов ($(100-$v2Pct)%)" -ForegroundColor Green
Write-Host "✅ V2: $v2 запросов ($v2Pct%)" -ForegroundColor Green
Write-Host "`n📊 Ожидание: 20% в V2 (±10%)" -ForegroundColor Cyan

if ($v2Pct -ge 10 -and $v2Pct -le 30) {
    Write-Host "✅ Canary работает корректно!`n" -ForegroundColor Green
} else {
    Write-Host "⚠️  Малая выборка, запустите с большим количеством`n" -ForegroundColor Yellow
}
