# Скрипт резервного копирования всех баз данных PostgreSQL
# Использует pg_dump для создания SQL дампов

param(
    [string]$BackupDir = ".\backups",
    [string]$ContainerName = "pgauto-node1",  # Primary node для бекапа
    [string]$User = "docker",
    [string]$Password = "secret"
)

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupPath = Join-Path $BackupDir $timestamp

# Создание директории для резервных копий
if (!(Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}
New-Item -ItemType Directory -Path $backupPath | Out-Null

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Скрипт резервного копирования PostgreSQL" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Каталог для копий: $backupPath" -ForegroundColor Yellow
Write-Host ""

# Единая база данных с pg_auto_failover
$db = "app_db"

Write-Host "Начато копирование базы $db..." -ForegroundColor Yellow

$dumpFile = Join-Path $backupPath "$db.sql"

try {
    # Вызов pg_dump через docker exec с выводом в stdout
    docker exec $ContainerName pg_dump -U $User -d $db -F plain | Out-File -Encoding UTF8 $dumpFile
    
    $size = (Get-Item $dumpFile).Length / 1KB
    Write-Host "   Готово: $db ($([math]::Round($size, 2)) KB)" -ForegroundColor Green
}
catch {
    Write-Host "   Ошибка копирования $db : $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Резервное копирование завершено" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "Каталог с копиями: $backupPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Созданные файлы:" -ForegroundColor Yellow
Get-ChildItem $backupPath | Format-Table Name, Length, LastWriteTime -AutoSize

# Очистка копий старше семи дней
$oldBackups = Get-ChildItem $BackupDir -Directory | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-7) }
if ($oldBackups) {
    Write-Host ""
    Write-Host "Удаление старых копий..." -ForegroundColor Yellow
    foreach ($old in $oldBackups) {
        Remove-Item $old.FullName -Recurse -Force
        Write-Host "   Удалено: $($old.Name)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Команда для восстановления:" -ForegroundColor Cyan
Write-Host "  .\scripts\restore.ps1 -BackupPath '$backupPath'" -ForegroundColor Gray
