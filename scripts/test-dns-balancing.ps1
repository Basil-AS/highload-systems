# Тест DNS Round Robin балансировки

Write-Host "`n=== DNS Round Robin Test ===" -ForegroundColor Cyan

# 1. Запуск контейнеров
Write-Host "`n1. Проверка контейнеров..."
$containers = docker ps --format "{{.Names}}" | Select-String "dnsmasq|nginx-dc"
if ($containers.Count -lt 4) {
    Write-Host "   Запуск контейнеров..." -ForegroundColor Yellow
    docker compose -p dns-lab -f docker-compose.dns.yml up -d --build 2>&1 | Out-Null
    Start-Sleep -Seconds 5
}
Write-Host "   ✓ Контейнеры запущены" -ForegroundColor Green

# 2. Проверка DNS возвращает все адреса
Write-Host "`n2. Проверка DNS возвращает все адреса..."
$dnsResult = docker exec search-dnsmasq nslookup -type=A search.lab 127.0.0.1 2>&1
$addresses = $dnsResult | Select-String "Address: 172\.30\.0\.\d+$"

if ($addresses.Count -eq 3) {
    Write-Host "   ✓ DNS возвращает 3 адреса" -ForegroundColor Green
    $addresses | ForEach-Object { Write-Host "     $($_.Line.Trim())" -ForegroundColor Gray }
} else {
    Write-Host "   ✗ DNS вернул $($addresses.Count) адресов (ожидалось 3)" -ForegroundColor Red
    exit 1
}

# 3. Проверка Round Robin ротации
Write-Host "`n3. Проверка Round Robin ротации порядка..."
$firstIPs = @()
1..5 | ForEach-Object {
    $result = docker exec search-dnsmasq nslookup search.lab 127.0.0.1 2>&1
    $firstIP = ($result | Select-String "^Address: 172\.30\.0\.\d+$" | Select-Object -First 1).Line -replace "Address:\s*", ""
    $firstIPs += $firstIP
}

$uniqueFirstIPs = $firstIPs | Select-Object -Unique
if ($uniqueFirstIPs.Count -ge 2) {
    Write-Host "   ✓ Порядок IP меняется (Round Robin работает)" -ForegroundColor Green
    Write-Host "   Первые IP в 5 запросах: $($firstIPs -join ', ')" -ForegroundColor Gray
} else {
    Write-Host "   ✗ Порядок IP не меняется (всегда: $($firstIPs[0]))" -ForegroundColor Red
    exit 1
}

# 4. Тест HTTP балансировки через реальные IP
Write-Host "`n4. Тест HTTP балансировки через DNS (30 запросов)..."
$stats = @{'172.30.0.11' = 0; '172.30.0.12' = 0; '172.30.0.13' = 0}

1..30 | ForEach-Object {
    # Делаем DNS запрос и берем первый IP (как делает клиент)
    $result = docker exec search-dnsmasq nslookup search.lab 127.0.0.1 2>&1
    $ip = ($result | Select-String "^Address: 172\.30\.0\.\d+$" | Select-Object -First 1).Line -replace "Address:\s*", ""
    
    # Делаем HTTP запрос к этому IP
    $response = docker exec search-dnsmasq wget -qO- --timeout=2 "http://${ip}/" 2>&1
    if ($response -match "nginx") {
        $stats[$ip]++
    }
}

# 5. Результаты
Write-Host "`n5. Результаты распределения:"
Write-Host "   DC1 (172.30.0.11): $($stats['172.30.0.11']) запросов ($([math]::Round($stats['172.30.0.11']/30*100))%)"
Write-Host "   DC2 (172.30.0.12): $($stats['172.30.0.12']) запросов ($([math]::Round($stats['172.30.0.12']/30*100))%)"
Write-Host "   DC3 (172.30.0.13): $($stats['172.30.0.13']) запросов ($([math]::Round($stats['172.30.0.13']/30*100))%)"

# 6. Оценка
$total = $stats['172.30.0.11'] + $stats['172.30.0.12'] + $stats['172.30.0.13']
$avg = $total / 3
$deviations = $stats.Values | ForEach-Object { [math]::Abs($_ - $avg) }
$maxDeviation = ($deviations | Measure-Object -Maximum).Maximum

Write-Host "`n6. Оценка равномерности:"
Write-Host "   Среднее: $([math]::Round($avg, 1)) запросов на DC"
Write-Host "   Макс. отклонение: $([math]::Round($maxDeviation, 1))"

if ($total -eq 30 -and $maxDeviation -le ($avg * 0.5)) {
    Write-Host "`n✓ Тест пройден: DNS Round Robin работает корректно`n" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n✗ Тест не пройден: распределение неравномерное`n" -ForegroundColor Red
    exit 1
}
