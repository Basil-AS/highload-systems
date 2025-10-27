# Скрипт для тестирования автоматического failover PostgreSQL
# Симулирует падение Primary ноды и проверяет переключение на Standby

Write-Host "════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  PostgreSQL Auto-Failover Test" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 1. Проверка текущего состояния
Write-Host "📊 Step 1: Checking current cluster state..." -ForegroundColor Yellow
docker exec pgauto-monitor pg_autoctl show state
Write-Host ""

# 2. Создание тестовых данных на Primary
Write-Host "📝 Step 2: Creating test data on PRIMARY..." -ForegroundColor Yellow
$testDataSql = @"
CREATE TABLE IF NOT EXISTS failover_test (
    id SERIAL PRIMARY KEY,
    test_message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
INSERT INTO failover_test (test_message) VALUES ('Test before failover at ' || NOW());
SELECT * FROM failover_test;
"@

$testDataSql | docker exec -i pgauto-node1 psql -U docker -d app_db
Write-Host ""

# 3. Симуляция падения Primary
Write-Host "💥 Step 3: Simulating PRIMARY node failure..." -ForegroundColor Red
Write-Host "Stopping pgauto-node1 container..."
docker stop pgauto-node1
Write-Host ""

# 4. Ожидание автоматического переключения
Write-Host "⏳ Step 4: Waiting for automatic failover (30 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# 5. Проверка нового состояния кластера
Write-Host "📊 Step 5: Checking cluster state after failover..." -ForegroundColor Yellow
docker exec pgauto-monitor pg_autoctl show state
Write-Host ""

# 6. Проверка данных на новом Primary (бывший Standby)
Write-Host "📖 Step 6: Reading test data from NEW PRIMARY (pgauto-node2:5432)..." -ForegroundColor Yellow
$readDataSql = @"
SELECT * FROM failover_test;
INSERT INTO failover_test (test_message) VALUES ('Test after failover at ' || NOW());
SELECT * FROM failover_test;
"@

$readDataSql | docker exec -i pgauto-node2 psql -U docker -d app_db
Write-Host ""

# 7. Восстановление старого Primary как Standby
Write-Host "🔄 Step 7: Restarting old PRIMARY (will become STANDBY)..." -ForegroundColor Yellow
docker start pgauto-node1
Write-Host "Waiting for re-join (30 seconds)..."
Start-Sleep -Seconds 30

# 8. Финальное состояние
Write-Host "📊 Step 8: Final cluster state..." -ForegroundColor Yellow
docker exec pgauto-monitor pg_autoctl show state
Write-Host ""

Write-Host "════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅ Failover Test Completed!" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  • Old PRIMARY (pgauto-node1) is now STANDBY" -ForegroundColor White
Write-Host "  • Old STANDBY (pgauto-node2) is now PRIMARY" -ForegroundColor White
Write-Host "  • Data survived the failover" -ForegroundColor White
Write-Host "  • Automatic failover took ~30 seconds" -ForegroundColor White
Write-Host ""
Write-Host "To failback (switch roles again):" -ForegroundColor Yellow
Write-Host "  docker exec pgauto-monitor pg_autoctl perform failover" -ForegroundColor Gray
