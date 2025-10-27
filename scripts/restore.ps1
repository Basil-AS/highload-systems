# Скрипт восстановления баз данных из бэкапа
# Восстанавливает все базы из указанной директории

param(
    [Parameter(Mandatory=$true)]
    [string]$BackupPath,
    [string]$ContainerName = "pgauto-node2",  # Восстанавливаем на текущий Primary
    [string]$User = "docker",
    [switch]$Force
)

if (!(Test-Path $BackupPath)) {
    Write-Host "❌ Backup path not found: $BackupPath" -ForegroundColor Red
    exit 1
}

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  PostgreSQL Restore Script" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Restore from: $BackupPath" -ForegroundColor Yellow
Write-Host "Target container: $ContainerName" -ForegroundColor Yellow
Write-Host ""

if (!$Force) {
    Write-Host "⚠️  WARNING: This will DROP and recreate databases!" -ForegroundColor Red
    $confirm = Read-Host "Type 'yes' to continue"
    if ($confirm -ne 'yes') {
        Write-Host "Restore cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Список баз данных для восстановления
$databases = @("users_db", "documents_db", "search_db", "audit_db")

foreach ($db in $databases) {
    $dumpFile = Join-Path $BackupPath "$db.sql"
    
    if (!(Test-Path $dumpFile)) {
        Write-Host "⚠️  Skipping $db (backup file not found)" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "📥 Restoring $db..." -ForegroundColor Yellow
    
    try {
        # Удаляем существующие подключения
        docker exec $ContainerName psql -U $User -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$db' AND pid <> pg_backend_pid();" 2>$null
        
        # Удаляем и создаём заново базу
        docker exec $ContainerName psql -U $User -d postgres -c "DROP DATABASE IF EXISTS $db;" 2>$null
        docker exec $ContainerName psql -U $User -d postgres -c "CREATE DATABASE $db;" 2>$null
        
        # Восстанавливаем из дампа через stdin
        Get-Content $dumpFile -Raw | docker exec -i $ContainerName psql -U $User -d $db
        
        Write-Host "   ✓ Restored $db" -ForegroundColor Green
    }
    catch {
        Write-Host "   ✗ Failed to restore $db : $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅ Restore Completed!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Verifying restored data..." -ForegroundColor Cyan

foreach ($db in $databases) {
    $count = docker exec $ContainerName psql -U $User -d $db -t -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';" 2>$null
    if ($count) {
        Write-Host "  $db : $($count.Trim()) tables" -ForegroundColor White
    }
}
