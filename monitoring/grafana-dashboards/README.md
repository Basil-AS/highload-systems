# Grafana Dashboards для ЛР4

## Доступ к Grafana

- **URL**: http://localhost:3000
- **Username**: admin
- **Password**: admin

## Импорт дашбордов

### Вариант 1: Через UI
1. Откройте Grafana: http://localhost:3000
2. Login: admin / admin
3. Перейдите в **Dashboards → Import**
4. Загрузите JSON файлы из папки `monitoring/grafana-dashboards/`

### Вариант 2: API (автоматический)
```powershell
.\scripts\import-grafana-dashboards.ps1
```

## Доступные дашборды

### 1. Services Overview
**Файл**: `services-overview.json`

**Метрики**:
- Request Rate by Service (RPS)
- Response Time p95
- Canary Traffic Distribution (V1 vs V2)
- Error Rate

**Цель**: Мониторинг всех микросервисов, отслеживание canary deployment

### 2. PostgreSQL Replication (TODO)
**Файл**: `postgres-replication.json`

**Метрики**:
- Replication Lag
- Primary/Secondary Status
- Connection Count
- Query Performance

### 3. System Resources (TODO)
**Файл**: `system-resources.json`

**Метрики**:
- CPU Usage
- Memory Usage
- Network I/O
- Disk I/O

## Prometheus Data Source

Grafana уже настроена для использования Prometheus:
- **URL**: http://search-prometheus:9090
- **Type**: Prometheus
- **Default**: Yes

## Проверка метрик

### User Service V1
```bash
curl http://localhost/metrics/user-v1
```

### User Service V2
```bash
curl http://localhost/metrics/user-v2
```

### Prometheus Targets
```bash
curl http://localhost:9090/api/v1/targets
```

## Queries Examples

### Canary Traffic Distribution
```promql
sum(rate(user_service_requests_total{version="v1"}[5m])) / sum(rate(user_service_requests_total[5m])) * 100
```

### Error Rate
```promql
rate(user_service_requests_total{status="error"}[5m])
```

### Response Time p95
```promql
histogram_quantile(0.95, rate(user_service_request_duration_seconds_bucket[5m]))
```

## Troubleshooting

### Не видно метрик
1. Проверьте что Prometheus собирает данные:
   ```bash
   curl http://localhost:9090/api/v1/targets
   ```
2. Проверьте что сервисы отдают метрики:
   ```bash
   curl http://localhost/metrics/user-v1
   ```

### Dashboard не загружается
- Убедитесь что Data Source "Prometheus" создан в Grafana
- Settings → Data Sources → Add Prometheus → http://search-prometheus:9090
