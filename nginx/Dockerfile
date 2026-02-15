# Estágio 1: Build do Angular
FROM node:20-alpine AS build
WORKDIR /app
COPY ./frontend/package*.json ./
RUN npm install
COPY ./frontend .
RUN npm run build -- --configuration production

# Estágio 2: Servir com Nginx
FROM nginx:alpine
# Copia o build do angular para a pasta do Nginx
COPY --from=build /app/dist/frontend/browser /var/www/frontend
# Copia sua configuração personalizada do Nginx
COPY ./nginx/default.conf /etc/nginx/conf.d/default.conf