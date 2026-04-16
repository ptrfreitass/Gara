# scripts/deploy.sh
#!/bin/bash

set -e

VERSION=$1
DOCKER_USERNAME=${DOCKER_USERNAME:-"preetow"}

if [ -z "$VERSION" ]; then
    echo "❌ Uso: ./deploy.sh <versao>"
    echo "   Exemplo: ./deploy.sh 1.0.0"
    exit 1
fi

# Verificar se .env.prod existe
if [ ! -f .env.prod ]; then
    echo "❌ Arquivo .env.prod não encontrado!"
    echo "   Copie .env.prod.example para .env.prod e configure"
    exit 1
fi

echo "🚀 Deploying version $VERSION..."
echo ""

# Carregar variáveis de ambiente
export $(cat .env.prod | xargs)
export VERSION=$VERSION
export DOCKER_USERNAME=$DOCKER_USERNAME

# Pull das imagens
echo "📥 Pulling images..."
docker-compose -f docker-compose.prod.yml pull
echo ""

# Parar containers antigos
echo "🛑 Stopping old containers..."
docker-compose -f docker-compose.prod.yml down
echo ""

# Subir novos containers
echo "🚀 Starting new containers..."
docker-compose -f docker-compose.prod.yml up -d
echo ""

# Aguardar containers iniciarem
echo "⏳ Waiting for containers to be healthy..."
sleep 10

# Rodar migrations (opcional)
echo "🔄 Running migrations..."
docker exec gara_backend_prod php artisan migrate --force
echo ""

echo "✅ Deploy completed!"
echo ""
echo "📊 Ver logs: docker-compose -f docker-compose.prod.yml logs -f"
echo "📍 Status: docker-compose -f docker-compose.prod.yml ps"