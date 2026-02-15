FROM nginx:alpine

# Remover config padrão
RUN rm /etc/nginx/conf.d/default.conf

# Copiar nossa config
COPY default.conf /etc/nginx/conf.d/default.conf

WORKDIR /var/www/html