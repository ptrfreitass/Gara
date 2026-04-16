# scripts/build-back.sh
#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar se a versão foi passada
if [ -z "$1" ]; then
    echo -e "${RED}❌ Erro: Versão não especificada${NC}"
    echo "Uso: ./scripts/build-back.sh <versão>"
    echo "Exemplo: ./scripts/build.sh 1.0.0"
    exit 1
fi

VERSION=$1
REGISTRY="preetow"

echo -e "${YELLOW}🔨 Construindo backend versão ${VERSION}...${NC}\n"

# Build Backend
echo -e "${GREEN}📦 Construindo backend...${NC}"
cd gara_backend
docker build -t ${REGISTRY}/gara_backend:${VERSION} -t ${REGISTRY}/gara_backend:latest -f ../docker/backend/Dockerfile .
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Backend falhou na construção${NC}"
    exit 1
fi
cd ..

echo -e "${GREEN}✅ Backend construído com sucesso!${NC}\n"


# Listar imagens criadas
echo -e "${YELLOW}📋 Imagens criadas:${NC}"
docker images | grep gara

echo -e "\n${GREEN}✅ Backend construído com sucesso!!${NC}"