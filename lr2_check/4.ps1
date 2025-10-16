Write-Host "`n=== Проверка /error (не кэшируется) ==="
1..3 | ForEach-Object {
    curl.exe -s -D - -o NUL http://localhost/error | Select-String "HTTP/1.1"
    curl.exe -s -D - -o NUL http://localhost/error | Select-String "X-Cache-Status"
    Start-Sleep -Milliseconds 500
}
