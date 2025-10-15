Write-Host "`n=== Проверка кэширования ==="
1..5 | ForEach-Object {
    curl.exe -s -D - -o NUL http://localhost/data | Select-String "X-Cache-Status"
    Start-Sleep -Seconds 1
}
