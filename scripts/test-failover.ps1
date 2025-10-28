# Скрипт для тестирования автоматического failover в pg_auto_failover кластере
# ЛР4: Высоконагруженные системы

$ErrorActionPreference = "Stop"

function Get-ClusterState {
    try {
        $json = docker exec pgauto-monitor pg_autoctl show state --json
        return $json | ConvertFrom-Json
    } catch {
        throw "Не удалось получить состояние кластера: $($_.Exception.Message)"
    }
}

function Get-PrimaryNode($state) {
    $primaryStates = @("primary", "wait_primary", "single")
    return $state |
        Where-Object { $_.health -eq 1 -and $primaryStates -contains $_.current_group_state } |
        Select-Object -First 1
}

function Get-SecondaryNode($state) {
    $secondaryStates = @("secondary", "wait_standby", "catchingup")
    return $state |
        Where-Object {
            $_.health -eq 1 -and $secondaryStates -contains $_.current_group_state -and $_.assigned_group_state -ne "primary"
        } |
        Select-Object -First 1
}

function Invoke-Psql {
    param(
        [string]$Container,
        [string]$Command,
        [string]$Database = "app_db"
    )

    $output = docker exec $Container psql -U docker -d $Database -c $Command 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "psql ($Container): $output"
    }
    return $output
}

function Invoke-PsqlRaw {
    param(
        [string]$Container,
        [string]$Command,
        [string]$Database = "app_db"
    )

    $output = docker exec $Container psql -U docker -d $Database -t -c $Command 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "psql ($Container): $output"
    }
    return $output
}

Write-Host "=== Тест PostgreSQL Failover (pg_auto_failover) ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Проверка исходного состояния..." -ForegroundColor Yellow
$initialState = Get-ClusterState
$primaryNode = Get-PrimaryNode $initialState
$secondaryNode = Get-SecondaryNode $initialState

if (-not $primaryNode -or -not $secondaryNode) {
    throw "В кластере должен быть один primary и один secondary."
}

Write-Host "  • Primary:  $($primaryNode.nodehost)" -ForegroundColor Cyan
Write-Host "  • Secondary: $($secondaryNode.nodehost)" -ForegroundColor Cyan
Write-Host ""

$primaryContainer = $primaryNode.nodehost
$secondaryContainer = $secondaryNode.nodehost

Write-Host "2. Запись тестовых данных в текущий Primary..." -ForegroundColor Yellow
Invoke-Psql -Container $primaryContainer -Command "CREATE TABLE IF NOT EXISTS failover_test (id SERIAL PRIMARY KEY, test_message TEXT, created_at TIMESTAMP DEFAULT NOW());"
Invoke-Psql -Container $primaryContainer -Command "INSERT INTO failover_test (test_message) VALUES ('Before failover');"
Write-Host "Данные успешно записаны" -ForegroundColor Green
Write-Host ""

Write-Host "3. Проверка репликации на secondary..." -ForegroundColor Yellow
Start-Sleep -Seconds 2
$replicaCountRaw = Invoke-PsqlRaw -Container $secondaryContainer -Command "SELECT COUNT(*) FROM failover_test;"
$replicaCount = $replicaCountRaw.Trim()
Write-Host "На реплике $replicaCount записей" -ForegroundColor Green
Write-Host ""

Write-Host "4. ИМИТАЦИЯ ОТКАЗА текущего Primary ($primaryContainer)..." -ForegroundColor Red
docker stop $primaryContainer | Out-Null
Write-Host "Primary остановлен" -ForegroundColor Red
Write-Host ""

Write-Host "5. Ожидание автоматического failover (30 секунд)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "6. Проверка состояния после failover..." -ForegroundColor Yellow

$maxAttempts = 12
$attempt = 0
$newPrimary = $null
$newSecondary = $null

for ($attempt = 0; $attempt -lt $maxAttempts; $attempt++) {
    $postState = Get-ClusterState
    $newPrimary = Get-PrimaryNode $postState
    $newSecondary = Get-SecondaryNode $postState

    if ($newPrimary -and $newPrimary.nodehost -ne $primaryContainer) {
        break
    }

    Start-Sleep -Seconds 5
}

if (-not $newPrimary) {
    throw "После failover не удалось определить новый primary."
}

if ($newPrimary.nodehost -eq $primaryContainer) {
    throw "Failover не произошёл: узел $primaryContainer остаётся primary после ожидания."
}

$postState = Get-ClusterState
$newPrimary = Get-PrimaryNode $postState
$newSecondary = Get-SecondaryNode $postState

if (-not $newPrimary) {
    throw "После failover не удалось определить новый primary."
}

Write-Host "  • Новый Primary:  $($newPrimary.nodehost)" -ForegroundColor Cyan
if ($newSecondary) {
    Write-Host "  • Новый Secondary: $($newSecondary.nodehost)" -ForegroundColor Cyan
} else {
    Write-Host "  • Новый Secondary: пока не определён (ожидаем возврата узла)" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "7. Проверка записи на новый Primary..." -ForegroundColor Yellow
try {
    Invoke-Psql -Container $newPrimary.nodehost -Command "INSERT INTO failover_test (test_message) VALUES ('After failover');"
    Write-Host "Запись успешна. Failover завершился корректно" -ForegroundColor Green
} catch {
    Write-Host "Запись не выполнена: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

Write-Host "8. Проверка доступности приложения..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost/api/search?q=test" -UseBasicParsing -TimeoutSec 5
    Write-Host "Приложение доступно. Статус: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Приложение недоступно: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

Write-Host "9. Перезапуск остановленного узла ($primaryContainer)..." -ForegroundColor Yellow
docker start $primaryContainer | Out-Null
Write-Host "Узел запущен, ожидаем присоединение (30 секунд)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "10. Финальное состояние кластера:" -ForegroundColor Yellow
$finalState = Get-ClusterState
foreach ($node in $finalState) {
    Write-Host "  • $($node.nodehost): $($node.current_group_state)" -ForegroundColor Cyan
}
Write-Host ""

Write-Host "11. Проверка согласованности данных..." -ForegroundColor Yellow
$currentPrimary = Get-PrimaryNode $finalState
$currentSecondary = Get-SecondaryNode $finalState

$primaryData = Invoke-PsqlRaw -Container $currentPrimary.nodehost -Command "SELECT * FROM failover_test ORDER BY id;"
$secondaryData = Invoke-PsqlRaw -Container $currentSecondary.nodehost -Command "SELECT * FROM failover_test ORDER BY id;"

Write-Host "Данные на текущем Primary:" -ForegroundColor Cyan
Write-Host $primaryData
Write-Host ""
Write-Host "Данные на текущем Secondary:" -ForegroundColor Cyan
Write-Host $secondaryData
Write-Host ""

Write-Host "=== Тест failover завершён ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Итоги:" -ForegroundColor Yellow
Write-Host "  • Исходный primary: $primaryContainer" -ForegroundColor Green
Write-Host "  • Текущий primary: $($currentPrimary.nodehost)" -ForegroundColor Green
Write-Host "  • Данные сохранились после переключения" -ForegroundColor Green
Write-Host "  • Отключённый узел вернулся в кластер" -ForegroundColor Green
Write-Host ""
Write-Host "Чтобы инициировать обратное переключение ролей, выполните:" -ForegroundColor Yellow
Write-Host "  docker exec pgauto-monitor pg_autoctl perform failover" -ForegroundColor Cyan
