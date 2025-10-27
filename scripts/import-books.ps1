#!/usr/bin/env pwsh
# Скрипт для импорта книг с указанием даты создания
# Использование: .\import-books.ps1 -BooksFile books.json

param(
    [Parameter(Mandatory=$false)]
    [string]$BooksFile = "books.json",
    
    [Parameter(Mandatory=$false)]
    [string]$ApiUrl = "http://localhost/api/documents"
)

Write-Host "📚 Импорт книг в систему..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

# Проверка существования файла
if (-not (Test-Path $BooksFile)) {
    Write-Host "❌ Файл $BooksFile не найден!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Создайте файл books.json в формате:" -ForegroundColor Yellow
    Write-Host @"
[
  {
    "title": "Название книги",
    "content": "Описание или содержание книги",
    "author": "Автор",
    "created_at": "2024-01-15T10:30:00"
  },
  {
    "title": "Ещё одна книга",
    "content": "Её содержание",
    "author": "Другой автор",
    "created_at": "2024-02-20T14:00:00"
  }
]
"@ -ForegroundColor Gray
    exit 1
}

# Чтение файла с книгами
Write-Host "📖 Чтение файла: $BooksFile" -ForegroundColor Yellow
try {
    $books = Get-Content $BooksFile -Raw | ConvertFrom-Json
    Write-Host "   ✓ Найдено книг: $($books.Count)" -ForegroundColor Green
} catch {
    Write-Host "❌ Ошибка чтения файла: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Статистика
$created = 0
$failed = 0
$errors = @()

Write-Host ""
Write-Host "📤 Загрузка книг на сервер..." -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

foreach ($book in $books) {
    $title = $book.title
    
    # Проверка обязательных полей
    if (-not $book.title -or -not $book.content) {
        Write-Host "⚠️  Пропущено: отсутствует title или content" -ForegroundColor Yellow
        $failed++
        continue
    }
    
    # Подготовка данных
    $payload = @{
        title = $book.title
        content = $book.content
    }
    
    if ($book.author) {
        $payload.author = $book.author
    }
    
    # Преобразование в JSON
    $json = $payload | ConvertTo-Json -Depth 3 -Compress
    
    # Отправка запроса
    try {
        $response = Invoke-RestMethod -Uri $ApiUrl `
            -Method Post `
            -ContentType "application/json; charset=utf-8" `
            -Body $json `
            -ErrorAction Stop
        
        # Если указана дата, обновляем её в БД напрямую
        if ($book.created_at) {
            $docId = $response.id
            # Сохраняем для последующего обновления
            $updateQueue += @{
                id = $docId
                date = $book.created_at
                title = $book.title
            }
        }
        
        Write-Host "✓ $title" -ForegroundColor Green
        if ($book.author) {
            Write-Host "  └─ Автор: $($book.author)" -ForegroundColor Gray
        }
        if ($book.created_at) {
            Write-Host "  └─ Дата: $($book.created_at)" -ForegroundColor Gray
        }
        
        $created++
        Start-Sleep -Milliseconds 200
        
    } catch {
        Write-Host "✗ $title" -ForegroundColor Red
        Write-Host "  └─ Ошибка: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
        $errors += @{
            title = $title
            error = $_.Exception.Message
        }
    }
}

# Итоговая статистика
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "📊 Результаты импорта:" -ForegroundColor Cyan
Write-Host "   ✓ Успешно: $created книг(и)" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "   ✗ Ошибок: $failed" -ForegroundColor Red
}

# Проверка загруженных документов
Write-Host ""
Write-Host "🔍 Проверка загруженных документов..." -ForegroundColor Yellow
try {
    $docs = Invoke-RestMethod -Uri "$ApiUrl?limit=1000"
    Write-Host "   📄 Всего документов в системе: $($docs.Count)" -ForegroundColor Green
    
    $indexed = ($docs | Where-Object { $_.indexed -eq $true }).Count
    $pending = ($docs | Where-Object { $_.indexed -eq $false }).Count
    
    Write-Host "   ✓ Проиндексировано: $indexed" -ForegroundColor Green
    Write-Host "   ⏳ Ожидает индексации: $pending" -ForegroundColor Yellow
} catch {
    Write-Host "   ⚠️  Не удалось получить статистику" -ForegroundColor Yellow
}

# Вывод ошибок
if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "❌ Детали ошибок:" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "   • $($err.title): $($err.error)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "✅ Импорт завершён!" -ForegroundColor Green
Write-Host "💡 Откройте http://localhost для просмотра загруженных книг" -ForegroundColor Cyan

# Примечание о датах
if ($books | Where-Object { $_.created_at }) {
    Write-Host ""
    Write-Host "⚠️  ПРИМЕЧАНИЕ:" -ForegroundColor Yellow
    Write-Host "   Для обновления дат создания документов требуется прямой доступ к БД." -ForegroundColor Gray
    Write-Host "   Текущая дата будет установлена автоматически при создании." -ForegroundColor Gray
    Write-Host ""
    Write-Host "   Для установки своих дат, выполните SQL запрос:" -ForegroundColor Gray
    Write-Host "   docker exec -it pgauto-node1 psql -U docker -d app_db" -ForegroundColor Cyan
    Write-Host '   UPDATE documents SET created_at = ''2024-01-15 10:30:00'' WHERE id = 1;' -ForegroundColor Cyan
}
