# Скрипт восстановления баз данных из бэкапа
# Восстанавливает все базы из указанной директории

param(
    [Parameter(Mandatory=$true)]
    [string]$BackupPath,
    [string]$ContainerName = "pgauto-node1",  # Primary node для восстановления
    [string]$User = "docker",
    [switch]$Force
)

if (!(Test-Path $BackupPath)) {
    Write-Host "❌ Каталог с резервной копией не найден: $BackupPath" -ForegroundColor Red
    exit 1
}

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Скрипт восстановления PostgreSQL" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Источник: $BackupPath" -ForegroundColor Yellow
Write-Host "Целевой контейнер: $ContainerName" -ForegroundColor Yellow
Write-Host ""

if (!$Force) {
    Write-Host "⚠️  ВНИМАНИЕ: база app_db будет пересоздана" -ForegroundColor Red
    $confirm = Read-Host "Введите 'yes' для продолжения"
    if ($confirm -ne 'yes') {
        Write-Host "Восстановление отменено." -ForegroundColor Yellow
        exit 0
    }
}

# Единая база данных
$db = "app_db"
$dumpFile = Join-Path $BackupPath "$db.sql"

if (!(Test-Path $dumpFile)) {
    Write-Host "❌ Файл резервной копии не найден: $dumpFile" -ForegroundColor Red
    exit 1
}

Write-Host "📥 Восстановление базы $db..." -ForegroundColor Yellow

try {
    # Завершение активных подключений
    docker exec $ContainerName psql -U $User -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$db' AND pid <> pg_backend_pid();" 2>$null
    
    # Повторное создание базы
    docker exec $ContainerName psql -U $User -d postgres -c "DROP DATABASE IF EXISTS $db;" 2>$null
    docker exec $ContainerName psql -U $User -d postgres -c "CREATE DATABASE $db;" 2>$null
    
    # Восстановление из дампа через stdin
    Get-Content $dumpFile -Raw | docker exec -i $ContainerName psql -U $User -d $db
    
    Write-Host "   ✓ База $db восстановлена" -ForegroundColor Green
}
catch {
    Write-Host "   ✗ Ошибка восстановления $db : $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅ Восстановление завершено" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Проверка восстановленных данных..." -ForegroundColor Cyan

$count = docker exec $ContainerName psql -U $User -d $db -t -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';" 2>$null
if ($count) {
    Write-Host "  $db : $($count.Trim()) таблиц" -ForegroundColor White
}
