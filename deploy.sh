#!/bin/bash
echo "🏗️ Construindo imagens de produção..."

# Build Backend
docker build -t frpreetin/gara-backend:latest -f Dockerfile.prod ./backend
docker push frpreetin/gara-backend:latest

# Build Frontend
docker build -t frpreetin/gara-frontend:latest -f Dockerfile.prod ./frontend
docker push frpreetin/gara-frontend:latest

echo "✅ Imagens enviadas para o Docker Hub!"