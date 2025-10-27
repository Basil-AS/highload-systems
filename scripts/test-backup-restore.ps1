# Скрипт тестирования backup/restore
# Создаёт тестовые данные, делает backup, восстанавливает и проверяет

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Backup/Restore Test Script" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Параметры
$ContainerName = "pgauto-node2"  # Текущий Primary после failover
$User = "docker"
$BackupDir = ".\backups"
$TestBackupBase = "test_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"

Write-Host "Step 1: Creating test data..." -ForegroundColor Yellow

# Создаём тестовые данные в каждой базе
$testData = @{
    "users_db" = "INSERT INTO users (username, email, hashed_password, full_name) VALUES ('testuser', 'test@backup.com', 'hash123', 'Test User');"
    "documents_db" = "INSERT INTO documents (title, content, author) VALUES ('Test Doc', 'Test content for backup', 'Test Author');"
    "search_db" = "INSERT INTO terms (term, document_count) VALUES ('testterm', 1);"
    "audit_db" = "INSERT INTO events (user_id, action, entity_type, entity_id, details) VALUES (1, 'TEST', 'backup', 999, '{""test"": true}');"
}

$originalCounts = @{}

foreach ($db in $testData.Keys) {
    # Вставляем тестовые данные
    docker exec $ContainerName psql -U $User -d $db -c $testData[$db] > $null 2>&1
    
    # Запоминаем количество строк ПОСЛЕ вставки
    $table = switch ($db) {
        "users_db" { "users" }
        "documents_db" { "documents" }
        "search_db" { "terms" }
        "audit_db" { "events" }
    }
    
    $count = docker exec $ContainerName psql -U $User -d $db -t -c "SELECT COUNT(*) FROM $table;" 2>$null | Select-Object -First 1
    if ($count) {
        $originalCounts[$db] = $count.Trim()
        Write-Host "  $db.$table : $($originalCounts[$db]) rows" -ForegroundColor White
    } else {
        Write-Host "  $db.$table : ERROR getting count" -ForegroundColor Red
        $originalCounts[$db] = "0"
    }
}

Write-Host ""
Write-Host "Step 2: Creating backup..." -ForegroundColor Yellow
$TestBackupDir = Join-Path $BackupDir $TestBackupBase
.\scripts\backup.ps1 -BackupDir $TestBackupDir -ContainerName $ContainerName -User $User

# Найти созданную директорию с timestamp (backup.ps1 добавляет свой timestamp)
$actualBackupDir = Get-ChildItem $TestBackupDir | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName

if (!(Test-Path $actualBackupDir)) {
    Write-Host "❌ Backup failed - directory not created" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Simulating data loss (dropping databases)..." -ForegroundColor Yellow

foreach ($db in $testData.Keys) {
    docker exec $ContainerName psql -U $User -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$db' AND pid <> pg_backend_pid();" > $null 2>&1
    docker exec $ContainerName psql -U $User -d postgres -c "DROP DATABASE IF EXISTS $db;" > $null 2>&1
    Write-Host "  Dropped $db" -ForegroundColor Red
}

Write-Host ""
Write-Host "Step 4: Restoring from backup..." -ForegroundColor Yellow
.\scripts\restore.ps1 -BackupPath $actualBackupDir -ContainerName $ContainerName -User $User -Force

Write-Host ""
Write-Host "Step 5: Verifying restored data..." -ForegroundColor Yellow

$allGood = $true

foreach ($db in $testData.Keys) {
    $table = switch ($db) {
        "users_db" { "users" }
        "documents_db" { "documents" }
        "search_db" { "terms" }
        "audit_db" { "events" }
    }
    
    $count = docker exec $ContainerName psql -U $User -d $db -t -c "SELECT COUNT(*) FROM $table;" 2>$null | Select-Object -First 1
    if ($count) {
        $restoredCount = $count.Trim()
    } else {
        $restoredCount = "ERROR"
    }
    
    # Сравнение с учетом типов (убираем лишние пробелы)
    $expected = $originalCounts[$db].Trim()
    $actual = $restoredCount.Trim()
    
    # Debug: показать типы и значения
    # Write-Host "DEBUG: '$db' -> expected='$expected' ($($expected.GetType().Name)), actual='$actual' ($($actual.GetType().Name))" -ForegroundColor Gray
    
    if ($expected -eq $actual) {
        Write-Host "  ✓ $db.$table : $actual rows (match!)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $db.$table : expected '$expected', got '$actual'" -ForegroundColor Red
        $allGood = $false
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan

if ($allGood) {
    Write-Host "  ✅ BACKUP/RESTORE TEST PASSED!" -ForegroundColor Green
} else {
    Write-Host "  ❌ BACKUP/RESTORE TEST FAILED!" -ForegroundColor Red
}

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test backup directory: $actualBackupDir" -ForegroundColor Yellow
