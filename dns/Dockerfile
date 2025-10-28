FROM alpine:latest

# Мы ставим dnsmasq
RUN apk add --no-cache dnsmasq

# Мы готовим папку для логов
RUN mkdir -p /var/log && touch /var/log/dnsmasq.log

# Мы копируем конфиг
COPY dnsmasq.conf /etc/dnsmasq.conf

# Мы открываем порт DNS
EXPOSE 5353/udp

# Мы запускаем dnsmasq в foreground
CMD ["dnsmasq", "--no-daemon", "--log-facility=/var/log/dnsmasq.log"]
