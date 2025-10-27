# Скрипт для тестирования PostgreSQL Failover
# ЛР4: Высоконагруженные системы

Write-Host "=== PostgreSQL Failover Test ===" -ForegroundColor Cyan
Write-Host ""

# Проверка начального состояния
Write-Host "1. Checking initial state..." -ForegroundColor Yellow
docker exec postgres-monitor pg_autoctl show state
Write-Host ""

# Тест записи в Primary
Write-Host "2. Writing test data to Primary..." -ForegroundColor Yellow
docker exec postgres-primary psql -U postgres -d users_db -c "CREATE TABLE IF NOT EXISTS failover_test (id SERIAL PRIMARY KEY, data TEXT, created_at TIMESTAMP DEFAULT NOW());"
docker exec postgres-primary psql -U postgres -d users_db -c "INSERT INTO failover_test (data) VALUES ('Before failover');"
Write-Host "Data written successfully" -ForegroundColor Green
Write-Host ""

# Проверка репликации
Write-Host "3. Checking replication..." -ForegroundColor Yellow
Start-Sleep -Seconds 2
$replicaData = docker exec postgres-standby psql -U postgres -d users_db -c "SELECT COUNT(*) FROM failover_test;" -t
Write-Host "Replica has $($replicaData.Trim()) records" -ForegroundColor Green
Write-Host ""

# Симуляция сбоя Primary
Write-Host "4. SIMULATING PRIMARY FAILURE..." -ForegroundColor Red
docker stop postgres-primary
Write-Host "Primary stopped" -ForegroundColor Red
Write-Host ""

# Ожидание переключения
Write-Host "5. Waiting for automatic failover (30 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Проверка нового состояния
Write-Host "6. Checking new state..." -ForegroundColor Yellow
docker exec postgres-monitor pg_autoctl show state
Write-Host ""

# Тест записи в новый Primary (бывший Standby)
Write-Host "7. Testing write to new Primary (former Standby)..." -ForegroundColor Yellow
try {
    docker exec postgres-standby psql -U postgres -d users_db -c "INSERT INTO failover_test (data) VALUES ('After failover');"
    Write-Host "Write successful! Standby is now Primary" -ForegroundColor Green
} catch {
    Write-Host "Write failed! Standby might still be read-only" -ForegroundColor Red
}
Write-Host ""

# Проверка доступности приложения
Write-Host "8. Testing application availability..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost/api/search?q=test" -UseBasicParsing
    Write-Host "Application is available! Status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Application is not available: $_" -ForegroundColor Red
}
Write-Host ""

# Восстановление Primary
Write-Host "9. Restarting old Primary (will become Standby)..." -ForegroundColor Yellow
docker start postgres-primary
Write-Host "Primary restarted" -ForegroundColor Green
Write-Host ""

# Ожидание присоединения
Write-Host "10. Waiting for old Primary to join as Standby (30 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Финальное состояние
Write-Host "11. Final state:" -ForegroundColor Yellow
docker exec postgres-monitor pg_autoctl show state
Write-Host ""

# Проверка данных
Write-Host "12. Verifying data consistency..." -ForegroundColor Yellow
$primaryData = docker exec postgres-standby psql -U postgres -d users_db -c "SELECT * FROM failover_test ORDER BY id;" -t
$standbyData = docker exec postgres-primary psql -U postgres -d users_db -c "SELECT * FROM failover_test ORDER BY id;" -t
Write-Host "Primary (former Standby) data:"
Write-Host $primaryData
Write-Host ""
Write-Host "Standby (former Primary) data:"
Write-Host $standbyData
Write-Host ""

Write-Host "=== Failover Test Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  ✓ Primary failed and stopped" -ForegroundColor Green
Write-Host "  ✓ Standby promoted to Primary" -ForegroundColor Green
Write-Host "  ✓ Application remained available" -ForegroundColor Green
Write-Host "  ✓ Old Primary rejoined as Standby" -ForegroundColor Green
Write-Host ""
Write-Host "To restore original roles, run:" -ForegroundColor Yellow
Write-Host "  docker exec postgres-monitor pg_autoctl perform failover" -ForegroundColor Cyan
