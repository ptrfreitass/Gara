# docker/backend/Dockerfile (versão alternativa com Alpine)
FROM php:8.3-cli-alpine

WORKDIR /app/gara_backend

# Instalar dependências do sistema
RUN apk add --no-cache \
    git \
    curl \
    postgresql-dev \
    postgresql-client \
    libzip-dev \
    zip \
    unzip \
    oniguruma-dev \
    libxml2-dev \
    curl-dev \
    openssl-dev \
    linux-headers \
    autoconf \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/*

# Instalar Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Instalar extensões PHP
RUN docker-php-ext-install \
    pdo \
    pdo_pgsql \
    pgsql \
    pcntl \
    zip \
    opcache \
    bcmath

# Instalar Redis e Swoole via PECL
RUN pecl install redis-6.3.0 swoole-6.1.6 \
    && docker-php-ext-enable redis swoole

# Configurar PHP
RUN cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini \
    && echo "memory_limit = 512M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "upload_max_filesize = 50M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "post_max_size = 50M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "max_execution_time = 300" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "opcache.enable = 1" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "opcache.memory_consumption = 256" >> /usr/local/etc/php/conf.d/custom.ini

# Copiar apenas composer.json e composer.lock primeiro (para cache do Docker)
COPY composer.json composer.lock ./

# Remover Laravel Pail e instalar dependências
RUN composer remove laravel/pail --no-interaction --no-update || true \
    && composer install --optimize-autoloader --no-interaction --no-scripts

# Copiar aplicação
COPY . .

# Dump autoload
RUN composer dump-autoload --optimize

# Criar diretórios e ajustar permissões
RUN mkdir -p storage/framework/{sessions,views,cache} \
    && mkdir -p storage/logs \
    && mkdir -p bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Expor porta
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8000/api/health || exit 1
