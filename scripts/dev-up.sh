#!/bin/bash

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Subindo ambiente de desenvolvimento...${NC}\n"

# Verificar se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker não está rodando!${NC}"
    exit 1
fi

# Verificar se docker-compose.dev.yml existe
if [ ! -f "docker-compose.dev.yml" ]; then
    echo -e "${RED}❌ Arquivo docker-compose.dev.yml não encontrado!${NC}"
    exit 1
fi

# Parar containers antigos (se existirem)
echo -e "${YELLOW}🛑 Parando containers antigos...${NC}"
docker-compose -f docker-compose.dev.yml down 2>/dev/null

# Subir containers
echo -e "${YELLOW}📦 Iniciando containers...${NC}\n"
docker-compose -f docker-compose.dev.yml up -d

# Aguardar containers iniciarem
echo -e "\n${YELLOW}⏳ Aguardando serviços iniciarem...${NC}"
sleep 5

# Verificar status
echo -e "\n${BLUE}📊 Status dos containers:${NC}"
docker-compose -f docker-compose.dev.yml ps

echo -e "\n${GREEN}✅ Ambiente iniciado!${NC}\n"
echo -e "${BLUE}📍 Serviços disponíveis:${NC}"
echo -e "   ${GREEN}Frontend:${NC}  http://localhost:4200"
echo -e "   ${GREEN}Backend:${NC}   http://localhost:8000"
echo -e "   ${GREEN}Nginx:${NC}     http://localhost"
echo -e "   ${GREEN}Postgres:${NC}  localhost:5432"
echo -e "   ${GREEN}Redis:${NC}     localhost:6379"
echo -e "\n${BLUE}📝 Comandos úteis:${NC}"
echo -e "   ${YELLOW}Ver logs:${NC}        docker-compose -f docker-compose.dev.yml logs -f"
echo -e "   ${YELLOW}Ver logs backend:${NC} docker-compose -f docker-compose.dev.yml logs -f backend"
echo -e "   ${YELLOW}Parar:${NC}            ./scripts/dev-down.sh"
echo -e "   ${YELLOW}Restart:${NC}          docker-compose -f docker-compose.dev.yml restart"
echo ""