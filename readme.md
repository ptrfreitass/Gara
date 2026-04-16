# GARA - Sistema Web

Stack completa com Angular, Laravel Octane, PostgreSQL, Redis e Docker.

## 🚀 Stack Tecnológica

- **Frontend**: Angular (SPA)
- **Backend**: Laravel 11 + Octane (Swoole)
- **Banco de Dados**: PostgreSQL 16
- **Cache/Filas**: Redis 7
- **Proxy Reverso**: Nginx
- **Email (Dev)**: Mailhog
- **Containerização**: Docker + Docker Compose

## 📁 Estrutura do Projeto
app/
├── gara_backend/ # API Laravel + Octane
├── gara_frontend/ # SPA Angular
├── docker/ # Configurações Docker
├── scripts/ # Scripts de automação
└── docker-compose.* # Orquestração de containers


## 🛠️ Desenvolvimento Local

### Pré-requisitos
- Docker 29.2.1
- Docker Compose 2.8.10
- Git

### Subir ambiente de desenvolvimento

```bash
# Subir todos os serviços com hot reload
./scripts/dev-up.sh

# Ou manualmente
docker-compose -f docker-compose.dev.yml up -d
Acessar serviços
Frontend: http://localhost:4200
Backend API: http://localhost:8000
Nginx (Proxy): http://localhost
Mailhog UI: http://localhost:8025
PostgreSQL: localhost:5432
Parar ambiente
bash
Copy
./scripts/dev-down.sh

# Ou manualmente
docker-compose -f docker-compose.dev.yml down