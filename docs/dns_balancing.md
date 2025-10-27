# DNS-балансировка (Round Robin DNS)

## Описание

DNS-балансировка реализована с помощью **dnsmasq** для симуляции гео-распределенной инфраструктуры с Round Robin распределением запросов.

## Архитектура

```
                    ┌─────────────────┐
                    │   DNS Client    │
                    │  (Application)  │
                    └────────┬────────┘
                             │
                             │ Query: search.local
                             ▼
                    ┌─────────────────┐
                    │    dnsmasq      │
                    │  (DNS Server)   │
                    │   Port: 5353    │
                    └────────┬────────┘
                             │
                             │ Round Robin Response:
                             │ 127.0.0.1 (33%)
                             │ 127.0.0.2 (33%)
                             │ 127.0.0.3 (33%)
                             ▼
              ┌──────────────┴──────────────┐
              │              │              │
     ┌────────▼────┐  ┌─────▼──────┐  ┌───▼────────┐
     │  Nginx DC1  │  │ Nginx DC2  │  │ Nginx DC3  │
     │  (8081)     │  │  (8082)    │  │  (8083)    │
     │ 172.20.0.10 │  │ 172.20.0.11│  │ 172.20.0.12│
     └─────────────┘  └────────────┘  └────────────┘
```

## Конфигурация

### dnsmasq.conf

Основные параметры:
- **Интерфейс**: `lo` (localhost)
- **Порт**: `5353` (чтобы не конфликтовать с системным DNS 53)
- **Round Robin**: 3 IP-адреса для `search.local`
- **TTL**: min 60s, max 3600s
- **Кэш**: 1000 записей

### Домены

| Домен | IP-адреса | Назначение |
|-------|-----------|------------|
| `search.local` | 127.0.0.1, 127.0.0.2, 127.0.0.3 | Round Robin балансировка (3 DC) |
| `api.search.local` | 127.0.0.1, 127.0.0.2 | API балансировка (2 DC) |
| `db-primary.search.local` | 127.0.0.1 | Primary БД |
| `db-secondary.search.local` | 127.0.0.2 | Secondary БД |
| `prometheus.search.local` | 127.0.0.1 | Мониторинг (без балансировки) |
| `grafana.search.local` | 127.0.0.1 | Визуализация (без балансировки) |

## Симуляция дата-центров

Три инстанса Nginx эмулируют географически распределенные дата-центры:

1. **DC1** (Data Center 1):
   - IP: `172.20.0.10`
   - Port: `8081`
   - Location: "Moscow" (симуляция)

2. **DC2** (Data Center 2):
   - IP: `172.20.0.11`
   - Port: `8082`
   - Location: "St. Petersburg" (симуляция)

3. **DC3** (Data Center 3):
   - IP: `172.20.0.12`
   - Port: `8083`
   - Location: "Novosibirsk" (симуляция)

## Запуск

### 1. Запуск DNS инфраструктуры

```powershell
# Запуск dnsmasq и 3 nginx инстансов
docker-compose -f docker-compose.dns.yml up -d

# Проверка контейнеров
docker ps | Select-String -Pattern "dns|dc"
```

Ожидаемый результат:
```
search-dnsmasq       Up
search-nginx-dc1     Up (port 8081)
search-nginx-dc2     Up (port 8082)
search-nginx-dc3     Up (port 8083)
```

### 2. Тестирование DNS резолвинга

```powershell
# Запрос через dnsmasq
nslookup search.local 127.0.0.1 -port=5353
```

Ожидаемый ответ (Round Robin):
```
Name:    search.local
Address: 127.0.0.1
Address: 127.0.0.2
Address: 127.0.0.3
```

### 3. Тестирование балансировки

```powershell
# Запуск автоматического теста
.\scripts\test-dns-balancing.ps1
```

Ожидаемый результат:
```
✅ DNS ROUND ROBIN РАБОТАЕТ КОРРЕКТНО!
  DC1 (8081): ~33% запросов
  DC2 (8082): ~33% запросов
  DC3 (8083): ~33% запросов
```

## Как работает Round Robin DNS

1. **Клиент** отправляет DNS-запрос для `search.local`
2. **dnsmasq** возвращает список IP-адресов в **циклическом порядке**:
   - Запрос 1: `127.0.0.1, 127.0.0.2, 127.0.0.3`
   - Запрос 2: `127.0.0.2, 127.0.0.3, 127.0.0.1`
   - Запрос 3: `127.0.0.3, 127.0.0.1, 127.0.0.2`
3. **Клиент** обычно использует **первый IP** из списка
4. **Результат**: равномерное распределение трафика между инстансами

## Преимущества

✅ **Простота**: не требует дополнительной логики в приложении  
✅ **Масштабируемость**: легко добавить новые IP-адреса  
✅ **Гео-распределение**: можно назначить IP-адреса из разных дата-центров  
✅ **Отказоустойчивость**: клиент может переключиться на другой IP при сбое  

## Недостатки

⚠️ **Кэширование**: клиент может кэшировать DNS-ответ (TTL)  
⚠️ **Нет health checks**: DNS не знает о доступности серверов  
⚠️ **Неравномерность**: распределение зависит от клиентов  
⚠️ **Sticky sessions**: нет гарантии попадания на тот же сервер  

## Альтернативы

- **GeoDNS**: маршрутизация по географическому положению клиента
- **Weighted Round Robin**: разные веса для разных серверов
- **Health-aware DNS**: динамическое удаление недоступных IP
- **Anycast**: один IP для нескольких серверов

## Мониторинг

### Логи dnsmasq

```powershell
# Просмотр логов DNS-запросов
docker logs search-dnsmasq --tail 50

# Фильтр по домену
docker logs search-dnsmasq 2>&1 | Select-String -Pattern "search.local"
```

### Метрики

Prometheus не собирает метрики напрямую с dnsmasq, но можно отслеживать:
- Количество запросов к каждому nginx инстансу
- Время ответа от каждого DC
- Ошибки подключения

## Использование в приложении

### Python (requests)

```python
import socket

# Резолвинг через кастомный DNS
socket.setdefaulttimeout(5)
host = socket.gethostbyname_ex("search.local")
# Вернет: ('search.local', [], ['127.0.0.1', '127.0.0.2', '127.0.0.3'])

# Можно выбрать случайный IP
import random
ip = random.choice(host[2])
```

### PowerShell

```powershell
# Резолвинг через dnsmasq
$result = Resolve-DnsName -Name "search.local" -Server "127.0.0.1" -Port 5353
$ips = $result.IPAddress

# Запрос к случайному IP
$ip = Get-Random -InputObject $ips
Invoke-WebRequest "http://${ip}/"
```

## Команды для управления

```powershell
# Запуск
docker-compose -f docker-compose.dns.yml up -d

# Остановка
docker-compose -f docker-compose.dns.yml down

# Перезапуск одного DC
docker restart search-nginx-dc2

# Просмотр конфигурации
docker exec search-dnsmasq cat /etc/dnsmasq.conf

# Проверка DNS-кэша
docker exec search-dnsmasq kill -USR1 1  # Дамп статистики в лог
```

## Итоги

DNS-балансировка реализована как **симуляция гео-распределенной инфраструктуры** с помощью dnsmasq и 3 инстансов nginx. Round Robin обеспечивает равномерное распределение трафика между "дата-центрами", что демонстрирует принципы работы DNS-балансировки в высоконагруженных системах.

**Статус**: ✅ Реализовано и протестировано
