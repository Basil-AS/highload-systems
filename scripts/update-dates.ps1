#!/usr/bin/env pwsh
# Скрипт для обновления дат создания документов в БД
# Использование: .\update-dates.ps1 -MappingFile dates.json

param(
    [Parameter(Mandatory=$false)]
    [string]$MappingFile = "dates.json"
)

Write-Host "📅 Обновление дат документов в базе данных..." -ForegroundColor Cyan

# Проверка файла с маппингом
if (-not (Test-Path $MappingFile)) {
    Write-Host "❌ Файл $MappingFile не найден!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Создайте файл dates.json в формате:" -ForegroundColor Yellow
    Write-Host @"
{
  "1": "2024-01-15T10:30:00",
  "2": "2024-02-20T14:00:00",
  "3": "2024-03-10T09:00:00"
}
"@ -ForegroundColor Gray
    Write-Host ""
    Write-Host "где ключи - это ID документов, а значения - даты создания" -ForegroundColor Gray
    exit 1
}

# Чтение маппинга
try {
    $mapping = Get-Content $MappingFile -Raw | ConvertFrom-Json
    $mappingObj = $mapping.PSObject.Properties
    Write-Host "✓ Загружено $($mappingObj.Count) маппингов" -ForegroundColor Green
} catch {
    Write-Host "❌ Ошибка чтения файла: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Проверка доступности PostgreSQL
Write-Host ""
Write-Host "🔍 Проверка подключения к PostgreSQL..." -ForegroundColor Yellow
$pgCheck = docker exec pgauto-node1 psql -U docker -d app_db -c "SELECT 1;" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Не удалось подключиться к PostgreSQL!" -ForegroundColor Red
    Write-Host "   Убедитесь, что контейнер pgauto-node1 запущен" -ForegroundColor Yellow
    exit 1
}
Write-Host "✓ Подключение установлено" -ForegroundColor Green

# Обновление дат
Write-Host ""
Write-Host "📝 Обновление дат документов..." -ForegroundColor Yellow

$updated = 0
$failed = 0

foreach ($prop in $mappingObj) {
    $docId = $prop.Name
    $date = $prop.Value
    
    # Формирование SQL запроса
    $sql = "UPDATE documents SET created_at = '$date', updated_at = '$date' WHERE id = $docId;"
    
    try {
        $result = docker exec pgauto-node1 psql -U docker -d app_db -c $sql 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Документ #$docId → $date" -ForegroundColor Green
            $updated++
        } else {
            Write-Host "✗ Документ #$docId: $result" -ForegroundColor Red
            $failed++
        }
    } catch {
        Write-Host "✗ Документ #$docId: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

# Итоги
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "📊 Результаты:" -ForegroundColor Cyan
Write-Host "   ✓ Обновлено: $updated документов" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "   ✗ Ошибок: $failed" -ForegroundColor Red
}

Write-Host ""
Write-Host "✅ Готово! Проверьте даты на http://localhost" -ForegroundColor Green
