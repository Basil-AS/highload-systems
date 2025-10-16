Write-Host "`n=== Проверка лимита на /data (5r/s, burst=5) ==="

$N = 50
$codes = 1..$N | ForEach-Object -Parallel {
    & curl.exe -s -o NUL -w "%{http_code}`n" http://localhost/data
} -ThrottleLimit $N

$codes | Sort-Object | Group-Object | ForEach-Object { "{0}: {1}" -f $_.Name, $_.Count }
Write-Host "`n429 = Too Many Requests → лимит сработал."
