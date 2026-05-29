# Dockerfile.frontend
FROM nginx:alpine

# Limpio default (opcional)
RUN rm -rf /usr/share/nginx/html/*

# Copio TODO el contenido del contexto (que ya es ./jarvis_frontend)
COPY . /usr/share/nginx/html/

# (Opcional) si quieres configurar gzip / headers:
# COPY nginx.conf /etc/nginx/conf.d/default.conf
