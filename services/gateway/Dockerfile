FROM nginx:alpine

# Copy configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy static files
COPY static /usr/share/nginx/html

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=3s CMD wget --quiet --tries=1 --spider http://localhost:80/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
