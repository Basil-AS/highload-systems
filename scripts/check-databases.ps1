#!/usr/bin/env pwsh
# Скрипт для проверки наполнения всех PostgreSQL баз данных

Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     🔍 ПРОВЕРКА НАПОЛНЕНИЯ POSTGRESQL БД                 ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# ============================================================
# Раздел 1. NODE1 (основная нода) - app_db
# ============================================================
Write-Host "1️⃣  NODE1 (основная) - localhost:5432/app_db" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

try {
    Write-Host "`n📋 Таблицы в базе app_db:" -ForegroundColor Cyan
    docker exec pgauto-node1 psql -U docker -d app_db -c "\dt"
    
    Write-Host "`n📊 Статистика документов:" -ForegroundColor Cyan
    $docStats = docker exec pgauto-node1 psql -U docker -d app_db -t -c "SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE indexed = true) as indexed,
        COUNT(*) FILTER (WHERE indexed = false) as pending
    FROM documents;"
    Write-Host $docStats -ForegroundColor White
    
    Write-Host "`n📄 Последние пять документов:" -ForegroundColor Cyan
    docker exec pgauto-node1 psql -U docker -d app_db -c "SELECT id, title, author, indexed, created_at FROM documents ORDER BY created_at DESC LIMIT 5;"
    
    Write-Host "`n📝 Статистика событий аудита:" -ForegroundColor Cyan
    $auditStats = docker exec pgauto-node1 psql -U docker -d app_db -t -c "SELECT 
        COUNT(*) as total_events,
        COUNT(DISTINCT event_type) as event_types,
        MIN(created_at) as first_event,
        MAX(created_at) as last_event
    FROM audit_events;"
    Write-Host $auditStats -ForegroundColor White
    
    Write-Host "`n📊 События аудита по типам:" -ForegroundColor Cyan
    docker exec pgauto-node1 psql -U docker -d app_db -c "SELECT event_type, COUNT(*) as count FROM audit_events GROUP BY event_type ORDER BY count DESC;"
    
    Write-Host "`n🔍 Партиции audit_events:" -ForegroundColor Cyan
    docker exec pgauto-node1 psql -U docker -d app_db -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables WHERE tablename LIKE 'audit_events%' ORDER BY tablename;"
    
    Write-Host "`n👥 Пользователи (при наличии):" -ForegroundColor Cyan
    docker exec pgauto-node1 psql -U docker -d app_db -c "SELECT COUNT(*) as total_users FROM users;" 2>$null
    if ($LASTEXITCODE -eq 0) {
        docker exec pgauto-node1 psql -U docker -d app_db -c "SELECT id, username, email, created_at FROM users ORDER BY created_at DESC LIMIT 5;" 2>$null
    } else {
        Write-Host "   (таблица users не существует или пуста)" -ForegroundColor Gray
    }
    
    Write-Host "`n✅ NODE1 проверен успешно" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Ошибка проверки NODE1: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================
# Раздел 2. NODE2 (вторичная нода) - app_db
# ============================================================
Write-Host "`n`n2️⃣  NODE2 (вторичная) - localhost:5433/app_db" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

try {
    Write-Host "`n📊 Проверка репликации (значения должны совпадать с NODE1):" -ForegroundColor Cyan
    
    $node2DocCount = docker exec pgauto-node2 psql -U docker -d app_db -t -c "SELECT COUNT(*) FROM documents;" 2>$null
    Write-Host "   Документов: $($node2DocCount.Trim())" -ForegroundColor White
    
    $node2AuditCount = docker exec pgauto-node2 psql -U docker -d app_db -t -c "SELECT COUNT(*) FROM audit_events;" 2>$null
    Write-Host "   Событий аудита: $($node2AuditCount.Trim())" -ForegroundColor White
    
    Write-Host "`n📄 Последние три документа для сравнения:" -ForegroundColor Cyan
    docker exec pgauto-node2 psql -U docker -d app_db -c "SELECT id, title, created_at FROM documents ORDER BY created_at DESC LIMIT 3;"
    
    Write-Host "`n⚠️  Примечание: NODE2 работает только на чтение" -ForegroundColor Yellow
    Write-Host "   Данные реплицируются автоматически с NODE1" -ForegroundColor Gray
    
    Write-Host "`n✅ NODE2 проверен успешно" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Ошибка проверки NODE2: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================
# Раздел 3. MONITOR - pg_auto_failover
# ============================================================
Write-Host "`n`n3️⃣  MONITOR - localhost:5434/pg_auto_failover" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

try {
    Write-Host "`n🔧 Состояние кластера:" -ForegroundColor Cyan
    docker exec pgauto-monitor psql -U autoctl_node -d pg_auto_failover -c "SELECT formation, nodeid, nodehost, nodeport, health, state FROM pgautofailover.node ORDER BY nodeid;"
    
    Write-Host "`n📊 События отказоустойчивости:" -ForegroundColor Cyan
    docker exec pgauto-monitor psql -U autoctl_node -d pg_auto_failover -c "SELECT * FROM pgautofailover.event ORDER BY event_time DESC LIMIT 10;"
    
    Write-Host "`n🔍 Таблицы в pg_auto_failover:" -ForegroundColor Cyan
    docker exec pgauto-monitor psql -U autoctl_node -d pg_auto_failover -c "\dt pgautofailover.*"
    
    Write-Host "`n✅ MONITOR проверен успешно" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Ошибка проверки MONITOR: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================
# ИТОГИ
# ============================================================
Write-Host "`n`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                  📊 ИТОГОВАЯ СТАТИСТИКА                   ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

try {
    $node1Docs = (docker exec pgauto-node1 psql -U docker -d app_db -t -c "SELECT COUNT(*) FROM documents;").Trim()
    $node1Events = (docker exec pgauto-node1 psql -U docker -d app_db -t -c "SELECT COUNT(*) FROM audit_events;").Trim()
    $node2Docs = (docker exec pgauto-node2 psql -U docker -d app_db -t -c "SELECT COUNT(*) FROM documents;").Trim()
    $node2Events = (docker exec pgauto-node2 psql -U docker -d app_db -t -c "SELECT COUNT(*) FROM audit_events;").Trim()
    
    Write-Host "NODE1 (основная):" -ForegroundColor White
    Write-Host "  📄 Документов: $node1Docs" -ForegroundColor Cyan
    Write-Host "  📝 Событий аудита: $node1Events" -ForegroundColor Cyan
    
    Write-Host "`nNODE2 (вторичная):" -ForegroundColor White
    Write-Host "  📄 Документов: $node2Docs" -ForegroundColor Cyan
    Write-Host "  📝 Событий аудита: $node2Events" -ForegroundColor Cyan
    
    if ($node1Docs -eq $node2Docs -and $node1Events -eq $node2Events) {
        Write-Host "`n✅ Репликация работает корректно" -ForegroundColor Green
        Write-Host "   NODE1 и NODE2 синхронизированы" -ForegroundColor Gray
    } else {
        Write-Host "`n⚠️  Возможна рассинхронизация" -ForegroundColor Yellow
        Write-Host "   NODE1 и NODE2 имеют разное количество записей" -ForegroundColor Gray
        Write-Host "   (при активной нагрузке значения выравниваются за 1-2 секунды)" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "⚠️  Не удалось собрать итоговую статистику" -ForegroundColor Yellow
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "✅ Проверка завершена" -ForegroundColor Green
Write-Host "`n💡 Для подключения из DBeaver или pgAdmin используйте:" -ForegroundColor Cyan
Write-Host "   • NODE1: localhost:5432, пользователь docker, пароль secret, база app_db" -ForegroundColor White
Write-Host "   • NODE2: localhost:5433, пользователь docker, пароль secret, база app_db" -ForegroundColor White
Write-Host "   • MONITOR: localhost:5434, пользователь autoctl_node, пароль secret, база pg_auto_failover" -ForegroundColor White
Write-Host ""
