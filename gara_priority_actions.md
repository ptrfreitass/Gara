# 🚨 GARA - AÇÕES PRIORITÁRIAS (CRÍTICO + ALTO)

**Data da Análise**: 15 de Março de 2026  
**Critério**: Itens classificados como 🔴 **CRÍTICO** e 🟠 **ALTO**, ordenados por **impacto vs esforço** (Princípio 80/20)

---

## 🔥 NÍVEL CRÍTICO (Ação Imediata - próximas 24-72h)

### 1. 🔐 **Revogar e rotacionar todas credenciais expostas no `.env.prod`**
**Severidade**: 🔴 CRÍTICO  
**Impacto**: Segurança total do sistema comprometida  
**Esforço**: Médio (2-4h)  
**Justificativa**:  
Arquivo `.env.prod` está commitado no repositório contendo:
- Senha PostgreSQL: `Pe@512151pp1632115125`
- Senha Redis: `gara_dev_pass_512151Pee@`
- Credenciais Gmail SMTP: `ptrfreitass@gmail.com` / `fxzheuvmrawzhqzf`

**Ações**:
1. Alterar TODAS as senhas imediatamente
2. Revogar app password do Gmail e gerar novo
3. Remover `.env.prod` do histórico Git: `git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch .env.prod' --prune-empty --tag-name-filter cat -- --all`
4. Force push (se repositório for privado) ou criar novo repositório
5. Atualizar `.gitignore` para garantir exclusão (já está, mas validar)
6. Criar `.env.prod` novo localmente no servidor (não versionar)

**Risco se não feito**: Acesso total ao banco de dados e sistema de email por terceiros.

---

### 2. 💾 **Implementar backup automatizado do PostgreSQL**
**Severidade**: 🔴 CRÍTICO  
**Impacto**: Perda total de dados em caso de falha de hardware  
**Esforço**: Baixo (1-2h)  
**Justificativa**:  
Servidor roda em notebook antigo sem nenhum backup configurado. Hardware consumidor tem alta taxa de falha.

**Ações**:
1. Criar script de backup diário:
```bash
#!/bin/bash
# /root/backup-db.sh
BACKUP_DIR="/var/backups/gara"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

docker exec gara_postgres_prod pg_dump -U gara -d gara_server | gzip > $BACKUP_DIR/gara_db_$DATE.sql.gz

# Manter apenas últimos 7 dias
find $BACKUP_DIR -name "gara_db_*.sql.gz" -mtime +7 -delete
```
2. Adicionar ao crontab: `0 2 * * * /root/backup-db.sh`
3. Configurar sync para cloud (Backblaze B2, Google Drive) com rclone:
```bash
rclone sync /var/backups/gara remote:gara-backups
```
4. Testar restore uma vez por mês

**Risco se não feito**: Perda irrecuperável de todos os dados financeiros dos usuários.

---

### 3. 🔒 **Configurar expiração de tokens Sanctum**
**Severidade**: 🔴 CRÍTICO  
**Impacto**: Tokens roubados válidos indefinidamente  
**Esforço**: Muito Baixo (15min)  
**Justificativa**:  
`'expiration' => null` permite que tokens de API nunca expirem. Se token vazar (XSS, shoulder surfing), atacante tem acesso permanente.

**Ações**:
1. Editar `gara_backend/config/sanctum.php` linha 50:
```php
'expiration' => env('SANCTUM_EXPIRATION', 60), // 60 minutos
```
2. Adicionar ao `.env.prod`: `SANCTUM_EXPIRATION=60`
3. Implementar refresh token no frontend (próxima sprint):
```typescript
// Interceptor para refresh antes de expirar
if (tokenExpiresIn < 5min) {
  await refreshToken();
}
```

**Risco se não feito**: Comprometimento de conta de usuário permanente após um único vazamento de token.

---

### 4. 🔐 **Adicionar senha ao Redis em produção**
**Severidade**: 🔴 CRÍTICO  
**Impacto**: Sessões e cache acessíveis por qualquer container na rede  
**Esforço**: Baixo (30min)  
**Justificativa**:  
Redis em produção não exige autenticação. Qualquer processo no `gara_network` pode ler sessões de usuários.

**Ações**:
1. Editar `docker-compose.prod.yml`:
```yaml
redis:
  image: redis:7-alpine
  command: redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes
  volumes:
    - redis_data_prod:/data
```
2. Adicionar ao `.env.prod`: `REDIS_PASSWORD=<senha_forte_gerada>`
3. Atualizar backend para usar senha (já configurado via `REDIS_PASSWORD` env)
4. Reiniciar containers

**Risco se não feito**: Roubo de sessões de usuários e dados de cache sensíveis.

---

### 5. 🔒 **Implementar HTTPS com TLS/SSL**
**Severidade**: 🔴 CRÍTICO  
**Impacto**: Tráfego em texto plano interceptável  
**Esforço**: Médio (2-3h)  
**Justificativa**:  
Mesmo via Tailscale, defesa em profundidade exige TLS. Credenciais e tokens trafegam em HTTP.

**Ações**:
1. Gerar certificado auto-assinado para Tailscale IP:
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout docker/nginx/ssl/gara.key \
  -out docker/nginx/ssl/gara.crt \
  -subj "/CN=<TAILSCALE_IP>"
```
2. Atualizar `docker/nginx/prod.conf`:
```nginx
server {
    listen 443 ssl http2;
    ssl_certificate /etc/nginx/ssl/gara.crt;
    ssl_certificate_key /etc/nginx/ssl/gara.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    # ... resto da config
}

server {
    listen 80;
    return 301 https://$host$request_uri;
}
```
3. Atualizar `APP_URL` no `.env.prod` para `https://`

**Risco se não feito**: Man-in-the-middle em rede Tailscale comprometida.

---

### 6. 🔐 **Remover credenciais hardcoded do `docker-compose.dev.yml`**
**Severidade**: 🔴 CRÍTICO  
**Impacto**: Credenciais de desenvolvimento expostas publicamente  
**Esforço**: Baixo (30min)  
**Justificativa**:  
Senhas de Postgres, Redis e Gmail estão em texto plano no arquivo versionado.

**Ações**:
1. Criar `.env.dev` (adicionar ao `.gitignore`):
```env
DB_DATABASE=gara_db
DB_USERNAME=gara_preto
DB_PASSWORD=<senha_dev>
REDIS_PASSWORD=<senha_dev>
MAIL_USERNAME=<email_dev>
MAIL_PASSWORD=<senha_dev>
```
2. Substituir valores hardcoded por `${DB_PASSWORD}`, etc.
3. Remover `.env.dev` do histórico se já foi commitado

**Risco se não feito**: Acesso não autorizado ao ambiente de desenvolvimento.

---

### 7. ⚙️ **Adicionar limites de recursos (CPU/RAM) nos containers**
**Severidade**: 🔴 CRÍTICO  
**Impacto**: OOM killer pode derrubar aplicação inteira  
**Esforço**: Baixo (30min)  
**Justificativa**:  
Notebook antigo com memória limitada. Containers sem limit podem causar crash do sistema operacional.

**Ações**:
1. Editar `docker-compose.prod.yml`, adicionar em cada serviço:
```yaml
backend:
  deploy:
    resources:
      limits:
        cpus: '1.0'
        memory: 1G
      reservations:
        memory: 512M

postgres:
  deploy:
    resources:
      limits:
        memory: 512M

redis:
  deploy:
    resources:
      limits:
        memory: 256M

nginx:
  deploy:
    resources:
      limits:
        memory: 128M
```
2. Testar load para validar se limits são adequados

**Risco se não feito**: Sistema operacional mata processos aleatórios em caso de saturação de memória.

---

### 8. 🔄 **Corrigir healthcheck do backend**
**Severidade**: 🔴 CRÍTICO  
**Impacto**: Container marcado como saudável mesmo falhando  
**Esforço**: Muito Baixo (15min)  
**Justificativa**:  
Healthcheck usa `curl localhost:8000` mas porta pode não estar acessível internamente.

**Ações**:
1. Editar `docker/backend/Dockerfile` linha 74-75:
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD php artisan octane:status || exit 1
```
Ou criar script PHP:
```dockerfile
HEALTHCHECK CMD php -r "echo file_get_contents('http://127.0.0.1:8000/api/health');" || exit 1
```

**Risco se não feito**: Nginx roteia tráfego para backend morto, resultando em 502/504.

---

### 9. 🔄 **Adicionar healthchecks no PostgreSQL e Redis em produção**
**Severidade**: 🔴 CRÍTICO  
**Impacto**: Backend inicia antes de dependências estarem prontas  
**Esforço**: Muito Baixo (10min)  
**Justificativa**:  
Compose dev tem healthchecks, mas prod não. Backend pode crashar no startup.

**Ações**:
1. Copiar de `docker-compose.dev.yml` para `docker-compose.prod.yml`:
```yaml
postgres:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U ${DB_USERNAME} -d ${DB_DATABASE}"]
    interval: 10s
    timeout: 5s
    retries: 5

redis:
  healthcheck:
    test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
    interval: 10s
    timeout: 5s
    retries: 5

backend:
  depends_on:
    postgres:
      condition: service_healthy
    redis:
      condition: service_healthy
```

**Risco se não feito**: Race condition no startup causa falhas intermitentes.

---

### 10. 🔄 **Migrations devem rodar ANTES do deploy**
**Severidade**: 🔴 CRÍTICO  
**Impacto**: Deploy com migration falhando deixa app quebrada  
**Esforço**: Baixo (30min)  
**Justificativa**:  
`scripts/deploy.sh` executa `docker-compose up` e DEPOIS `docker exec ... migrate`. Se migration falhar, app já está servindo tráfego com schema desatualizado.

**Ações**:
1. Editar `scripts/deploy.sh`:
```bash
# Após pull, rodar migrations em container temporário
echo "🔄 Running migrations..."
docker run --rm \
  --network gara_network \
  -e APP_KEY=${APP_KEY} \
  -e DB_HOST=postgres \
  -e DB_DATABASE=${DB_DATABASE} \
  -e DB_USERNAME=${DB_USERNAME} \
  -e DB_PASSWORD=${DB_PASSWORD} \
  ${DOCKER_USERNAME}/gara_backend:${VERSION} \
  php artisan migrate --force

if [ $? -ne 0 ]; then
    echo "❌ Migration failed! Aborting deploy."
    exit 1
fi

# Só então sobe os containers
docker-compose -f docker-compose.prod.yml up -d
```

**Risco se não feito**: Deploy com schema incompatível causa 500 errors para todos os usuários.

---

## 🟠 NÍVEL ALTO (Próximas 1-2 semanas)

### 11. 🔒 **Implementar Security Headers HTTP no Nginx**
**Severidade**: 🟠 ALTO  
**Impacto**: Vulnerabilidades a clickjacking, XSS, MIME sniffing  
**Esforço**: Muito Baixo (15min)  
**Justificativa**:  
Produção não tem headers de segurança configurados.

**Ações**:
```nginx
# Adicionar no bloco server do prod.conf
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;
```

---

### 12. 🔒 **Configurar SANCTUM_STATEFUL_DOMAINS para produção**
**Severidade**: 🟠 ALTO  
**Impacto**: CSRF protection pode falhar em SPA  
**Esforço**: Muito Baixo (5min)  
**Justificativa**:  
Config hardcoded para `localhost`, mas produção usa IP Tailscale.

**Ações**:
1. Adicionar ao `.env.prod`:
```env
SANCTUM_STATEFUL_DOMAINS=<tailscale_ip>,<tailscale_ip>:80,<tailscale_ip>:443
```

---

### 13. 🔒 **Publicar e configurar CORS explicitamente**
**Severidade**: 🟠 ALTO  
**Impacto**: CORS muito permissivo ou muito restritivo  
**Esforço**: Baixo (30min)  
**Justificativa**:  
Usando defaults do Laravel sem customização.

**Ações**:
```bash
php artisan config:publish cors
```
Editar `config/cors.php`:
```php
'allowed_origins' => [env('FRONTEND_URL')],
'allowed_methods' => ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
'allowed_headers' => ['Content-Type', 'Authorization', 'X-Requested-With'],
'exposed_headers' => [],
'max_age' => 3600,
'supports_credentials' => true,
```

---

### 14. 🔒 **Adicionar rate limiting em rotas de autenticação restantes**
**Severidade**: 🟠 ALTO  
**Impacto**: Brute force em registro e verificação de email  
**Esforço**: Muito Baixo (10min)  
**Justificativa**:  
`/auth/register` e `/auth/resend-verification` não têm throttling.

**Ações**:
```php
Route::middleware('throttle:10,60')->group(function () {
    Route::post('register', [AuthController::class, 'register']);
    Route::post('resend-verification', [VerificationController::class, 'resend']);
});
```

---

### 15. 🔒 **Ativar SESSION_ENCRYPT em produção**
**Severidade**: 🟠 ALTO  
**Impacto**: Dados de sessão em Redis legíveis  
**Esforço**: Muito Baixo (2min)  
**Justificativa**:  
`.env.example` tem `SESSION_ENCRYPT=false`.

**Ações**:
```env
SESSION_ENCRYPT=true
```

---

### 16. 🔒 **PostgreSQL com sslmode=require em produção**
**Severidade**: 🟠 ALTO  
**Impacto**: Conexão DB pode ser não criptografada  
**Esforço**: Médio (requer configuração de certificados)  
**Justificativa**:  
`sslmode=prefer` permite fallback para conexão não criptografada.

**Ações**:
1. Gerar certificado SSL para PostgreSQL
2. Configurar `ssl = on` no `postgresql.conf`
3. Atualizar `.env.prod`: `DB_SSLMODE=require`

---

### 17. 🔒 **Reduzir LOG_LEVEL para warning em produção**
**Severidade**: 🟠 ALTO  
**Impacto**: Logs excessivos com dados sensíveis  
**Esforço**: Muito Baixo (2min)  
**Justificativa**:  
`LOG_LEVEL=debug` loga requests completos.

**Ações**:
```env
LOG_LEVEL=warning
LOG_STACK=daily
LOG_DAILY_DAYS=7
```

---

### 18. 🔒 **Implementar auditoria de dependências**
**Severidade**: 🟠 ALTO  
**Impacto**: Vulnerabilidades conhecidas não detectadas  
**Esforço**: Baixo (adicionar ao CI quando implementado)  
**Justificativa**:  
Nenhuma evidência de `composer audit` ou `npm audit`.

**Ações**:
1. Localmente: `composer audit && npm audit`
2. No futuro CI/CD: adicionar step de auditoria

---

### 19. ⚙️ **Usar versões pinadas de imagens Docker**
**Severidade**: 🟠 ALTO  
**Impacto**: Breaking changes em atualizações automáticas  
**Esforço**: Muito Baixo (5min)  
**Justificativa**:  
`nginx:alpine`, `postgres:16-alpine` podem atualizar major versions.

**Ações**:
```yaml
nginx:
  image: nginx:1.25-alpine
postgres:
  image: postgres:16.2-alpine
redis:
  image: redis:7.2-alpine
```

---

### 20. ⚙️ **Validar que VERSION está definida em deploy**
**Severidade**: 🟠 ALTO  
**Impacto**: Deploy pode puxar imagem errada  
**Esforço**: Muito Baixo (5min)  
**Justificativa**:  
`docker-compose.prod.yml` usa `${VERSION}` mas não valida se existe.

**Ações**:
```bash
# No scripts/deploy.sh
if [ -z "$VERSION" ]; then
    echo "❌ VERSION não definida no .env.prod"
    exit 1
fi
```

---

### 21. 🚀 **Otimizar configuração Swoole**
**Severidade**: 🟠 ALTO  
**Impacto**: Performance degradada ou memory leaks  
**Esforço**: Médio (1-2h de testes)  
**Justificativa**:  
Nenhuma configuração explícita de workers, max_requests.

**Ações**:
1. Criar `config/octane.php` customizado:
```php
'swoole' => [
    'options' => [
        'worker_num' => env('SWOOLE_WORKERS', 4),
        'task_worker_num' => env('SWOOLE_TASK_WORKERS', 2),
        'max_request' => env('SWOOLE_MAX_REQUESTS', 1000),
        'package_max_length' => 10 * 1024 * 1024, // 10MB
    ],
],
```
2. Adicionar ao `.env.prod`:
```env
SWOOLE_WORKERS=2  # Ajustar para CPU do notebook
SWOOLE_TASK_WORKERS=1
SWOOLE_MAX_REQUESTS=500
```

---

### 22. 🚀 **Descomentar DisconnectFromDatabases no Octane**
**Severidade**: 🟠 ALTO  
**Impacto**: Conexões DB podem vazar  
**Esforço**: Muito Baixo (2min + testes)  
**Justificativa**:  
Listener está comentado sem justificativa.

**Ações**:
```php
OperationTerminated::class => [
    FlushOnce::class,
    FlushTemporaryContainerInstances::class,
    DisconnectFromDatabases::class,  // Descomentar
    CollectGarbage::class,  // Descomentar também
],
```

---

### 23. 🚀 **Configurar Redis maxmemory e eviction policy em produção**
**Severidade**: 🟠 ALTO  
**Impacto**: Redis pode consumir toda RAM  
**Esforço**: Baixo (15min)  
**Justificativa**:  
Dev tem `redis.conf`, prod não.

**Ações**:
```yaml
redis:
  image: redis:7.2-alpine
  command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 256mb --maxmemory-policy allkeys-lru --appendonly yes
```

---

### 24. 🚀 **Implementar PgBouncer para connection pooling**
**Severidade**: 🟠 ALTO  
**Impacto**: Esgotamento de conexões PostgreSQL  
**Esforço**: Médio (2-3h)  
**Justificativa**:  
Swoole workers abrem múltiplas conexões.

**Ações**:
1. Adicionar container PgBouncer no `docker-compose.prod.yml`:
```yaml
pgbouncer:
  image: edoburu/pgbouncer
  environment:
    DATABASE_URL: postgres://${DB_USERNAME}:${DB_PASSWORD}@postgres:5432/${DB_DATABASE}
    MAX_CLIENT_CONN: 100
    DEFAULT_POOL_SIZE: 20
```
2. Backend conecta em `pgbouncer` ao invés de `postgres`

---

### 25. 🚀 **Reduzir configurações de memória do PostgreSQL**
**Severidade**: 🟠 ALTO  
**Impacto**: Postgres consome muita RAM para hardware limitado  
**Esforço**: Baixo (15min)  
**Justificativa**:  
`shared_buffers=256MB` é muito para notebook antigo.

**Ações**:
```sql
ALTER SYSTEM SET shared_buffers = '128MB';
ALTER SYSTEM SET effective_cache_size = '512MB';
```

---

### 26. 🚀 **Implementar lazy loading no Angular**
**Severidade**: 🟠 ALTO  
**Impacto**: Bundle inicial muito grande  
**Esforço**: Médio (depende da estrutura)  
**Justificativa**:  
Não vi configuração explícita de lazy loading.

**Ações**:
1. Verificar se módulos de feature usam `loadChildren`
2. Se não, refatorar:
```typescript
{
  path: 'finance',
  loadChildren: () => import('./features/finance/finance.routes').then(m => m.FINANCE_ROUTES)
}
```

---

### 27. 🔄 **Implementar pipeline CI/CD básico**
**Severidade**: 🟠 ALTO  
**Impacto**: Deploys manuais propensos a erro  
**Esforço**: Alto (4-6h inicial)  
**Justificativa**:  
Tudo é manual atualmente.

**Ações**:
1. Criar `.github/workflows/ci.yml`:
```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Backend tests
        run: |
          cd gara_backend
          composer install
          php artisan test
      - name: Frontend tests
        run: |
          cd gara_frontend
          npm ci
          npm test
```

---

### 28. 🔄 **Implementar rolling updates no deploy**
**Severidade**: 🟠 ALTO  
**Impacto**: Downtime em todo deploy  
**Esforço**: Alto (depende de múltiplas instâncias)  
**Justificativa**:  
`docker-compose down` causa interrupção total.

**Ações**:
1. Usar `docker-compose up -d --no-deps --build <service>` para updates individuais
2. Ou implementar Docker Swarm / Kubernetes (overkill para projeto solo)
3. Alternativa simples: Blue-Green com 2 stacks

---

### 29. 🔄 **Criar testes automatizados básicos**
**Severidade**: 🟠 ALTO  
**Impacto**: Regressões não detectadas  
**Esforço**: Alto (mas incremental)  
**Justificativa**:  
Cobertura = 0%.

**Ações**:
1. Priorizar testes para:
   - Auth (login, register, logout)
   - Finance (criar transação, categorias)
   - Capabilities (verificar permissões)
2. Exemplo:
```php
test('user can login with valid credentials', function () {
    $user = User::factory()->create();
    $response = $this->postJson('/api/auth/login', [
        'identifier' => $user->email,
        'password' => 'password',
    ]);
    $response->assertOk()->assertJsonStructure(['token']);
});
```

---

### 30. 🔄 **Documentar estratégia de rollback**
**Severidade**: 🟠 ALTO  
**Impacto**: Deploy com problema não tem reversão  
**Esforço**: Baixo (1h documentação)  
**Justificativa**:  
Nenhum plano documentado.

**Ações**:
1. Criar `docs/rollback.md`:
```markdown
## Rollback para versão anterior
1. Identificar versão anterior: `docker images | grep gara`
2. Atualizar .env.prod: `VERSION=<versao_anterior>`
3. Executar: `./scripts/deploy.sh <versao_anterior>`
4. Se migrations quebraram, restaurar backup de DB
```
2. Manter N-1 imagens no registry

---

### 31. 🔄 **Adicionar validação de qualidade no build**
**Severidade**: 🟠 ALTO  
**Impacto**: Código com erros de sintaxe/formatação em produção  
**Esforço**: Baixo (30min)  
**Justificativa**:  
Build não executa linters.

**Ações**:
```bash
# No scripts/build.sh, antes do docker build:
echo "🔍 Validando código..."
cd gara_backend && composer pint --test && cd ..
cd gara_frontend && npm run lint && cd ..
```

---

### 32. 📊 **Implementar monitoramento básico de infraestrutura**
**Severidade**: 🟠 ALTO  
**Impacto**: Problemas não detectados até falha total  
**Esforço**: Médio (2-3h)  
**Justificativa**:  
Nenhuma visibilidade de CPU/RAM/Disco.

**Ações**:
1. Instalar Netdata (mais simples) ou cAdvisor + Prometheus + Grafana:
```bash
docker run -d --name=netdata \
  --pid=host \
  --network=host \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  netdata/netdata
```
2. Acessar via `http://<tailscale_ip>:19999`

---

### 33. 📊 **Implementar agregação de logs**
**Severidade**: 🟠 ALTO  
**Impacto**: Troubleshooting muito difícil  
**Esforço**: Médio (2-4h)  
**Justificativa**:  
Logs espalhados em múltiplos containers.

**Ações**:
1. Opção simples: Loki + Promtail + Grafana
2. Ou apenas centralizar em syslog:
```yaml
logging:
  driver: syslog
  options:
    syslog-address: "udp://localhost:514"
```

---

### 34. 📊 **Configurar sistema de alertas**
**Severidade**: 🟠 ALTO  
**Impacto**: Falhas não notificadas  
**Esforço**: Baixo (1h)  
**Justificativa**:  
Ninguém é alertado se sistema cair.

**Ações**:
1. Usar serviço gratuito Healthchecks.io:
```bash
# No crontab
*/5 * * * * curl -fsS --retry 3 https://hc-ping.com/<uuid> > /dev/null
```
2. Ou self-hosted Uptime Kuma:
```bash
docker run -d --name uptime-kuma -p 3001:3001 louislam/uptime-kuma:1
```

---

### 35. 📊 **Melhorar health endpoints**
**Severidade**: 🟠 ALTO  
**Impacto**: Health checks não detectam problemas reais  
**Esforço**: Baixo (1h)  
**Justificativa**:  
`/health` é apenas JSON estático.

**Ações**:
```php
Route::get('/health', function () {
    $checks = [
        'database' => DB::connection()->getPdo() !== null,
        'redis' => Redis::ping() === '+PONG',
        'disk' => disk_free_space('/') > 1024*1024*1024, // >1GB
        'octane_workers' => \Laravel\Octane\Facades\Octane::isRunning(),
    ];
    
    $healthy = !in_array(false, $checks);
    return response()->json($checks, $healthy ? 200 : 503);
});
```

---

### 36. 📊 **Configurar rotação de logs**
**Severidade**: 🟠 ALTO  
**Impacto**: Disco cheio por logs  
**Esforço**: Muito Baixo (5min)  
**Justificativa**:  
Laravel usa `single` driver sem limite.

**Ações**:
```env
LOG_CHANNEL=daily
LOG_DAILY_DAYS=7
```

---

### 37. 📊 **Adicionar métricas de aplicação**
**Severidade**: 🟠 ALTO  
**Impacto**: Performance desconhecida  
**Esforço**: Médio (depende da solução)  
**Justificativa**:  
Nenhuma coleta de latência, throughput, error rate.

**Ações**:
1. Dev: Laravel Telescope
```bash
composer require laravel/telescope --dev
php artisan telescope:install
```
2. Prod: Prometheus exporter ou APM (futuro)

---

### 38. 💾 **Migrar backups para cloud storage**
**Severidade**: 🟠 ALTO  
**Impacto**: Backup local não protege contra perda física  
**Esforço**: Baixo (1-2h)  
**Justificativa**:  
Após implementar backup local (#2), precisa ser off-site.

**Ações**:
```bash
# Instalar rclone
curl https://rclone.org/install.sh | sudo bash

# Configurar remote (Backblaze B2, GDrive, S3)
rclone config

# Adicionar ao script de backup
rclone sync /var/backups/gara b2:gara-backups --progress
```

---

### 39. 💾 **Configurar Redis persistence em produção**
**Severidade**: 🟠 ALTO  
**Impacto**: Perda de sessões em restart  
**Esforço**: Muito Baixo (já está no comando - validar)  
**Justificativa**:  
Comando Redis prod já tem `--appendonly yes`, mas validar se está funcionando.

**Ações**:
```bash
docker exec gara_redis_prod redis-cli CONFIG GET appendonly
# Deve retornar "yes"
```

---

### 40. 🏗️ **Implementar versionamento de API**
**Severidade**: 🟠 ALTO  
**Impacto**: Breaking changes quebram frontend  
**Esforço**: Médio (refatoração de rotas)  
**Justificativa**:  
Rotas sem prefixo de versão.

**Ações**:
1. Criar `routes/api_v1.php` com rotas atuais
2. Atualizar `bootstrap/app.php`:
```php
->withRouting(
    api: __DIR__.'/../routes/api_v1.php',
    apiPrefix: 'api/v1',
)
```
3. Frontend usa `/api/v1/`

---

### 41. 🏗️ **Migrar tarefas lentas para jobs assíncronos**
**Severidade**: 🟠 ALTO  
**Impacto**: Requests lentos bloqueando workers  
**Esforço**: Médio (depende da quantidade)  
**Justificativa**:  
Email sends, por exemplo, são síncronos.

**Ações**:
```php
// Ao invés de
Mail::send(...);

// Usar
Mail::queue(...);

// Ou criar job
SendVerificationEmail::dispatch($user);
```

---

### 42. 🏗️ **Padronizar responses da API**
**Severidade**: 🟠 ALTO  
**Impacto**: Frontend com tratamento inconsistente  
**Esforço**: Médio (criar classes base)  
**Justificativa**:  
Responses variam entre endpoints.

**Ações**:
```php
// app/Http/Resources/ApiResponse.php
class ApiResponse {
    public static function success($data, $message = null, $code = 200) {
        return response()->json([
            'success' => true,
            'message' => $message,
            'data' => $data,
        ], $code);
    }
    
    public static function error($message, $code = 400, $errors = null) {
        return response()->json([
            'success' => false,
            'message' => $message,
            'errors' => $errors,
        ], $code);
    }
}
```

---

---

## 📊 RESUMO DA PRIORIZAÇÃO

**Total de Ações Críticas + Altas**: 42 itens

### Próximas 72 horas (Crítico):
- Items #1-10 — Foco em **segurança de credenciais, backup, autenticação e estabilidade**

### Próximas 2 semanas (Alto):
- Items #11-42 — Foco em **hardening de segurança, performance, CI/CD básico e observabilidade**

### ROI (Return on Investment) estimado:
- **Top 3 maior impacto**: #1 (credenciais), #2 (backup), #3 (tokens)
- **Top 3 menor esforço**: #3 (tokens), #9 (healthchecks), #15 (session encrypt)

### Estratégia 80/20:
Implementar os **10 itens críticos** resolve aproximadamente **80% dos riscos** com **20% do esforço total** (estimado em 12-16 horas de trabalho).

---

**Prioridade absoluta**: **#1 (credenciais expostas)** e **#2 (backup)** devem ser resolvidos HOJE.
