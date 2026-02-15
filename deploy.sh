#!/bin/bash

VERSION="v1"

echo "🚀 Iniciando Build de Produção ($VERSION)..."

# Build Backend
docker build --target production -t preetin/gara-backend:$VERSION -f backend/Dockerfile .

# Build Nginx + Angular
docker build -t preetin/gara-nginx:$VERSION -f nginx/Dockerfile .

echo "⬆️ Enviando para o Docker Hub..."
docker push preetin/gara-backend:$VERSION
docker push preetin/gara-nginx:$VERSION

echo "✅ Imagens enviadas com sucesso!"