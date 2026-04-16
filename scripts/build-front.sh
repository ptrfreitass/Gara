# scripts/build-front.sh
#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar se a versão foi passada
if [ -z "$1" ]; then
    echo -e "${RED}❌ Erro: Versão não especificada${NC}"
    echo "Uso: ./scripts/build-front.sh <versão>"
    echo "Exemplo: ./scripts/build.sh 1.0.0"
    exit 1
fi

VERSION=$1
REGISTRY="preetow"

# Build Frontend
echo -e "${GREEN}📦 Construindo frontend...${NC}"
cd gara_frontend
docker build -t ${REGISTRY}/gara_frontend:${VERSION} -t ${REGISTRY}/gara_frontend:latest -f ../docker/frontend/Dockerfile .
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Frontend falhou na construção${NC}"
    exit 1
fi
cd ..

echo -e "${GREEN}✅ Frontend construído com sucesso!${NC}\n"

# Listar imagens criadas
echo -e "${YELLOW}📋 Imagens criadas:${NC}"
docker images | grep gara

echo -e "\n${GREEN}✅ Todas imagens construídas com sucesso!!${NC}"
echo -e "${YELLOW}💡 Próximos passos:${NC}"