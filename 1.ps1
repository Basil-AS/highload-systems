Write-Host "`n=== Проверка балансировки ==="
1..10 | ForEach-Object {
    curl.exe -s http://localhost/status | ConvertFrom-Json | Select-Object port
    Start-Sleep -Milliseconds 300
}
