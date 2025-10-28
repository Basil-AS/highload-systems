# Скрипт тестирования backup/restore
# Создаёт тестовые данные, делает backup, восстанавливает и проверяет

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Тест резервного копирования и восстановления" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Параметры
$ContainerName = "pgauto-node1"  # Primary node
$User = "docker"
$BackupDir = ".\backups"
$TestBackupBase = "test_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"

Write-Host "Шаг 1: Создание тестовых данных..." -ForegroundColor Yellow

# База данных
$db = "app_db"

# Создаём тестовые данные в разных таблицах
$testData = @{
    "users" = "INSERT INTO users (username, email, hashed_password, full_name) VALUES ('testuser', 'test@backup.com', 'hash123', 'Test User');"
    "documents" = "INSERT INTO documents (title, content, author) VALUES ('Test Doc', 'Test content for backup', 'Test Author');"
    "terms" = "INSERT INTO terms (term, document_count) VALUES ('testterm', 1);"
}

$originalCounts = @{}

foreach ($table in $testData.Keys) {
    # Вставляем тестовые данные
    docker exec $ContainerName psql -U $User -d $db -c $testData[$table] > $null 2>&1
    
    # Запоминается количество строк после вставки
    $count = docker exec $ContainerName psql -U $User -d $db -t -c "SELECT COUNT(*) FROM $table;" 2>$null | Select-Object -First 1
    if ($count) {
        $originalCounts[$table] = $count.Trim()
        Write-Host "  $table : $($originalCounts[$table]) строк" -ForegroundColor White
    } else {
        Write-Host "  $table : ошибка получения количества" -ForegroundColor Red
        $originalCounts[$table] = "0"
    }
}

Write-Host ""
Write-Host "Шаг 2: Создание резервной копии..." -ForegroundColor Yellow
$TestBackupDir = Join-Path $BackupDir $TestBackupBase
.\scripts\backup.ps1 -BackupDir $TestBackupDir -ContainerName $ContainerName -User $User

# Найти созданную директорию с timestamp (backup.ps1 добавляет свой timestamp)
$actualBackupDir = Get-ChildItem $TestBackupDir | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName

if (!(Test-Path $actualBackupDir)) {
    Write-Host "❌ Не удалось создать директорию с резервной копией" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Шаг 3: Имитация потери данных (удаление таблиц)..." -ForegroundColor Yellow

foreach ($table in $testData.Keys) {
    docker exec $ContainerName psql -U $User -d $db -c "DELETE FROM $table WHERE true;" > $null 2>&1
    Write-Host "  Таблица $table очищена" -ForegroundColor Red
}

Write-Host ""
Write-Host "Шаг 4: Восстановление из резервной копии..." -ForegroundColor Yellow
.\scripts\restore.ps1 -BackupPath $actualBackupDir -ContainerName $ContainerName -User $User -Force

Write-Host ""
Write-Host "Шаг 5: Проверка восстановленных данных..." -ForegroundColor Yellow

$allGood = $true

foreach ($table in $testData.Keys) {
    $count = docker exec $ContainerName psql -U $User -d $db -t -c "SELECT COUNT(*) FROM $table;" 2>$null | Select-Object -First 1
    if ($count) {
        $restoredCount = $count.Trim()
    } else {
        $restoredCount = "ERROR"
    }
    
    # Сравнение с учетом типов (убираются лишние пробелы)
    $expected = $originalCounts[$table].Trim()
    $actual = $restoredCount.Trim()
    
    if ($expected -eq $actual) {
        Write-Host "  ✓ $table : $actual строк (совпадает)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $table : ожидалось '$expected', получено '$actual'" -ForegroundColor Red
        $allGood = $false
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan

if ($allGood) {
    Write-Host "  ✅ Проверка резервного копирования и восстановления успешно пройдена" -ForegroundColor Green
} else {
    Write-Host "  ❌ Проверка резервного копирования и восстановления завершилась с ошибками" -ForegroundColor Red
}

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Каталог тестовой резервной копии: $actualBackupDir" -ForegroundColor Yellow
