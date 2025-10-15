Write-Host "`n=== Проверка антишквала на /status (10r/s, burst=10) ==="

$N = 80
$codes = 1..$N | ForEach-Object -Parallel {
    & curl.exe -s -o NUL -w "%{http_code}`n" http://localhost/status
} -ThrottleLimit $N

$codes | Sort-Object | Group-Object | ForEach-Object { "{0}: {1}" -f $_.Name, $_.Count }
Write-Host "`n429 = Too Many Requests → антишквал работает."
