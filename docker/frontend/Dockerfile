# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

# Copiar package.json e package-lock.json
COPY package*.json ./

# Atualizar npm
RUN npm install -g npm@11.12.0

# Instalar dependências
RUN npm ci
# Copiar código fonte
COPY . .

# Build da aplicação
RUN npm run build -- --configuration production

# Stage 2: Production
FROM nginx:alpine

# Copiar configuração customizada do Nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copiar build do Angular 
COPY --from=builder /app/dist/gara_frontend/browser /usr/share/nginx/html

# Expor porta
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8000/ || exit 1

# Iniciar Nginx
CMD ["nginx", "-g", "daemon off;"]