Write-Host "`n=== Проверка отсутствия кэширования POST ==="

$g = curl.exe -s -D - -o NUL http://localhost/data | Select-String "X-Cache-Status"
Write-Host ("GET    X-Cache-Status: {0}" -f ($g -replace 'X-Cache-Status:\s*',''))

$p = curl.exe -s -X POST -D - -o NUL http://localhost/data | Select-String "X-Cache-Status"
if ($p) {
    Write-Host ("POST   X-Cache-Status: {0}" -f ($p -replace 'X-Cache-Status:\s*',''))
} else {
    Write-Host "POST   X-Cache-Status: (нет заголовка, кэш не используется)"
}

$g2 = curl.exe -s -D - -o NUL http://localhost/data | Select-String "X-Cache-Status"
Write-Host ("GET2   X-Cache-Status: {0}" -f ($g2 -replace 'X-Cache-Status:\s*',''))
