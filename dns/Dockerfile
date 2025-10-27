FROM alpine:latest

# Установка dnsmasq
RUN apk add --no-cache dnsmasq

# Создание директории для логов
RUN mkdir -p /var/log && touch /var/log/dnsmasq.log

# Копирование конфигурации
COPY dnsmasq.conf /etc/dnsmasq.conf

# Expose DNS порт
EXPOSE 5353/udp

# Запуск dnsmasq в foreground режиме
CMD ["dnsmasq", "--no-daemon", "--log-facility=/var/log/dnsmasq.log"]
