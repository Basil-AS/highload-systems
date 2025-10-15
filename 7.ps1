Write-Host "`n=== Проверка заголовков статики ==="
curl.exe -sI -H "Accept-Encoding: gzip" http://localhost/static/css/style.css |
    Select-String "HTTP/1.1|Cache-Control|ETag|Content-Encoding"
