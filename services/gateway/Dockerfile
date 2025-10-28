FROM nginx:alpine

# Мы копируем конфигурацию
COPY nginx.conf /etc/nginx/nginx.conf

# Мы копируем статические файлы
COPY static /usr/share/nginx/html

# Мы открываем порты
EXPOSE 80 443

# Мы добавляем healthcheck
HEALTHCHECK --interval=30s --timeout=3s CMD wget --quiet --tries=1 --spider http://localhost:80/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
