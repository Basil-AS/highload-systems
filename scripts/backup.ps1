# Скрипт резервного копирования всех баз данных PostgreSQL
# Использует pg_dump для создания SQL дампов

param(
    [string]$BackupDir = ".\backups",
    [string]$ContainerName = "pgauto-node1",
    [string]$User = "docker",
    [string]$Password = "secret"
)

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupPath = Join-Path $BackupDir $timestamp

# Создаём директорию для бэкапов
if (!(Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}
New-Item -ItemType Directory -Path $backupPath | Out-Null

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  PostgreSQL Backup Script" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Backup directory: $backupPath" -ForegroundColor Yellow
Write-Host ""

# Список баз данных для бэкапа
$databases = @("users_db", "documents_db", "search_db", "audit_db")

foreach ($db in $databases) {
    Write-Host "📦 Backing up $db..." -ForegroundColor Yellow
    
    $dumpFile = Join-Path $backupPath "$db.sql"
    
    try {
        # Используем pg_dump через docker exec с выводом в stdout
        docker exec $ContainerName pg_dump -U $User -d $db -F plain | Out-File -Encoding UTF8 $dumpFile
        
        $size = (Get-Item $dumpFile).Length / 1KB
        Write-Host "   ✓ Backed up $db ($([math]::Round($size, 2)) KB)" -ForegroundColor Green
    }
    catch {
        Write-Host "   ✗ Failed to backup $db : $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅ Backup Completed!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "Backup location: $backupPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files created:" -ForegroundColor Yellow
Get-ChildItem $backupPath | Format-Table Name, Length, LastWriteTime -AutoSize

# Очистка старых бэкапов (старше 7 дней)
$oldBackups = Get-ChildItem $BackupDir -Directory | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-7) }
if ($oldBackups) {
    Write-Host ""
    Write-Host "🗑️  Cleaning up old backups..." -ForegroundColor Yellow
    foreach ($old in $oldBackups) {
        Remove-Item $old.FullName -Recurse -Force
        Write-Host "   Deleted: $($old.Name)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "To restore from this backup:" -ForegroundColor Cyan
Write-Host "  .\scripts\restore.ps1 -BackupPath '$backupPath'" -ForegroundColor Gray
