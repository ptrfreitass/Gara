-- docker/postgres/init.sql
-- Script de inicialização do PostgreSQL para Gara App
-- Idempotente: pode ser executado múltiplas vezes sem erro

-- Criar extensões necessárias (se não existirem)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Configurações de performance
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_io_concurrency = 200;

-- Criar usuário (se não existir)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'gara_user') THEN
        CREATE ROLE gara_user WITH LOGIN PASSWORD 'gara_password';
    END IF;
END
$$;

-- Criar banco de dados (se não existir)
SELECT 'CREATE DATABASE gara_db OWNER gara_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'gara_db')\gexec

-- Conectar ao banco gara_db e configurar permissões
\c gara_db

-- Garantir que o usuário tenha todas as permissões
GRANT ALL PRIVILEGES ON DATABASE gara_db TO gara_user;
GRANT ALL PRIVILEGES ON SCHEMA public TO gara_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO gara_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO gara_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO gara_user;

-- Criar extensões no banco gara_db (se não existirem)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Configurar timezone
SET timezone = 'UTC';