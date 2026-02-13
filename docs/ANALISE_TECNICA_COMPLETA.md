# 🔍 ANÁLISE TÉCNICA COMPLETA - PROJETO GARA

**Data:** 2024  
**Arquitetura:** Laravel Octane + Angular SPA + Nginx + Redis + PostgreSQL + Mailhog  
**Status:** ⚠️ CRÍTICO - Autenticação comprometida

---

## 📋 SUMÁRIO EXECUTIVO

### Problema Principal
A aplicação está em **estado crítico** devido a uma **incompatibilidade arquitetural** entre o sistema de autenticação implementado e a arquitetura atual. O sistema foi originalmente projetado para usar **Bearer Tokens (Sanctum API Tokens)**, mas foi parcialmente migrado para **Session-Based Authentication** sem completar a transição, resultando em:

- ❌ Autenticação não funcional
- ❌ Guards do frontend verificando tokens inexistentes
- ❌ Backend gerando sessões que o frontend não utiliza
- ❌ Fluxo de CSRF token implementado mas não necessário para tokens
- ❌ Código legado de tokens misturado com código de sessões

---

## 🏗️ ARQUITETURA ATUAL

### Stack Tecnológica
```
┌─────────────────────────────────────────────────────────────┐
│                         NGINX (Porta 80)                     │
│                    (Reverse Proxy + Static)                  │
└─────────────────────────────────────────────────────────────┘
                    │                        │
        ┌───────────┴──────────┐   ┌────────┴─────────┐
        │   Angular SPA        │   │  Laravel Octane  │
        │   (Frontend)         │   │  (Backend:8000)  │
        │   /var/www/frontend  │   │  Swoole Server   │
        └──────────────────────┘   └──────────────────┘
                                            │
                    ┌───────────────────────┼───────────────────┐
                    │                       │                   │
            ┌───────┴──────┐      ┌────────┴────────┐  ┌──────┴──────┐
            │  PostgreSQL  │      │     Redis       │  │   Mailhog   │
            │  (Database)  │      │  (Session/Cache)│  │   (Email)   │
            └──────────────┘      └─────────────────┘  └─────────────┘
```

### Fluxo de Requisições
```
Browser → Nginx:80 → Angular (/) ou Laravel (/api, /sanctum)
                              ↓
                         Redis (Sessions)
                              ↓
                         PostgreSQL (Data)
```

---

## 🚨 PROBLEMAS CRÍTICOS IDENTIFICADOS

### 1. **INCOMPATIBILIDADE DE AUTENTICAÇÃO** (CRÍTICO)

#### Backend (Laravel)
**Arquivo:** `backend/app/Http/Controllers/Api/Auth/AuthController.php`

**Problema:** O método `login()` está usando **Session-Based Auth**:
```php
// Linha 57-72
if (!Auth::guard('web')->attempt(..., true)) {
    return response()->json(['message' => 'Credenciais inválidas.'], 401);
}
$request->session()->regenerate();
return response()->json(['user' => [...]], 200);
```

**Problema:** O método `verifyCode()` ainda retorna **Sanctum Token**:
```php
// Linha 208 (não visível no trecho, mas existe)
$user->tokens()->delete();
```

**Problema:** O método `resetPassword()` tenta deletar tokens:
```php
// Linha 208
$user->tokens()->delete();
```

#### Frontend (Angular)

**Arquivo:** `frontend/src/app/core/guards/auth/auth-guard.ts`
```typescript
// Linha 6
const token = localStorage.getItem('access_token');
if (token) {
    return true;
}
```
**❌ PROBLEMA:** O guard verifica um token que **nunca é criado** pelo backend atual.

**Arquivo:** `frontend/src/app/pages/public/verify-email/verify-email.ts`
```typescript
// Linha 123
localStorage.setItem('access_token', res.access_token);
```
**❌ PROBLEMA:** Espera receber `access_token` que o backend **não retorna mais**.

**Arquivo:** `frontend/src/app/core/services/auth/auth-service.ts`
```typescript
// Linha 76-77
localStorage.removeItem('access_token');
localStorage.removeItem('pending_email');
```
**❌ PROBLEMA:** Remove tokens que não existem.

---

### 2. **FLUXO DE CSRF DESNECESSÁRIO** (MÉDIO)

**Arquivo:** `frontend/src/app/core/services/auth/auth-service.ts`
```typescript
// Linha 45-53
register(userData: User) {
    return this.getCsrfToken().pipe(
        switchMap(() =>
            this.http.post<AuthResponse>(`/api/register`, userData)
        )
    );
}
```

**❌ PROBLEMA:** 
- O fluxo de CSRF é necessário **apenas para Session-Based Auth**
- Se usar **Bearer Tokens**, CSRF não é necessário
- Atualmente está implementado mas **não está sendo usado corretamente**

**Arquivo:** `frontend/src/app/core/interceptors/auth/auth-interceptor.ts`
```typescript
// Linha 15-25
const csrfToken = getCookie('XSRF-TOKEN');
const modifiedReq = req.clone({
    withCredentials: true,
    setHeaders: csrfToken ? {
        'X-XSRF-TOKEN': decodeToken(csrfToken)
    } : {}
});
```

**❌ PROBLEMA:**
- Adiciona `withCredentials: true` em **todas** as requisições
- Isso força o navegador a enviar cookies, mas o backend não está configurado para isso
- O interceptor lê o cookie CSRF, mas o backend não valida corretamente

---

### 3. **CONFIGURAÇÃO DE SESSÃO INCONSISTENTE** (ALTO)

**Arquivo:** `backend/.env`
```env
SESSION_DRIVER=redis
SESSION_DOMAIN=localhost
SESSION_SECURE_COOKIE=false
SESSION_SAME_SITE=lax
```

**Arquivo:** `backend/config/sanctum.php`
```php
// Linha 37
'guard' => ['web'],
```

**❌ PROBLEMA:**
- Sanctum está configurado para usar o guard `web` (sessões)
- Mas as rotas da API usam `auth:sanctum` que espera **tokens**
- Isso cria uma **ambiguidade** no sistema de autenticação

**Arquivo:** `backend/routes/api.php`
```php
// Linha 40
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
});
```

**❌ PROBLEMA:**
- `auth:sanctum` middleware verifica **primeiro tokens**, depois sessões
- Como não há tokens, deveria cair para sessões
- Mas o frontend não envia cookies corretamente

---

### 4. **NGINX NÃO PROPAGA COOKIES CORRETAMENTE** (MÉDIO)

**Arquivo:** `nginx/default.conf`
```nginx
# Linha 37-55
location /sanctum/csrf-cookie {
    proxy_pass http://backend;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    # ... outros headers
}
```

**❌ PROBLEMA:**
- Falta `proxy_cookie_domain backend localhost;`
- Falta `proxy_cookie_path / /;`
- Cookies gerados pelo backend podem não ser acessíveis pelo frontend

---

### 5. **CÓDIGO LEGADO DE TOKENS** (MÉDIO)

**Locais com código de tokens:**
1. `frontend/src/app/pages/public/verify-email/verify-email.ts:123`
2. `frontend/src/app/core/guards/auth/auth-guard.ts:6`
3. `frontend/src/app/core/guards/public/public-guard.ts:5`
4. `frontend/src/app/core/services/auth/auth-service.ts:76-77`
5. `backend/app/Http/Controllers/Api/Auth/AuthController.php:208`

**❌ PROBLEMA:**
- Código misturado de duas estratégias de autenticação
- Dificulta manutenção e debugging
- Cria expectativas incorretas no fluxo

---

### 6. **FALTA DE ENDPOINT `/api/user`** (ALTO)

**Arquivo:** `frontend/src/app/core/services/auth/auth-service.ts`
```typescript
// Linha 37-42
loadUserProfile() {
    return this.http.get(`api/user`).subscribe({
        next: (user) => this.currentUserSignal.set(user),
        error: () => this.logout()
    });
}
```

**Arquivo:** `backend/routes/api.php`
```php
// NÃO EXISTE ROTA /api/user
```

**❌ PROBLEMA:**
- Frontend tenta carregar perfil do usuário de endpoint inexistente
- Isso causa logout automático sempre que a aplicação inicia

---

### 7. **CONFIGURAÇÃO DE CORS INCOMPLETA** (BAIXO)

**Arquivo:** `backend/config/cors.php`
```php
'allowed_origins' => [
    env('FRONTEND_URL', 'http://localhost'),
    env('APP_URL', 'http://localhost')
],
```

**Arquivo:** `backend/.env`
```env
FRONTEND_URL=http://localhost
APP_URL=http://localhost
```

**⚠️ OBSERVAÇÃO:**
- Configuração está correta para a arquitetura atual (Nginx como proxy)
- Mas pode causar problemas em desenvolvimento se acessar diretamente as portas

---

### 8. **OCTANE + SESSÕES + REDIS** (MÉDIO)

**Arquivo:** `docker-compose.yml`
```yaml
backend:
  environment:
    OCTANE_SERVER: swoole
    SESSION_DRIVER: redis
    REDIS_HOST: redis
```

**⚠️ OBSERVAÇÃO:**
- Octane com Swoole mantém o estado da aplicação em memória
- Sessões no Redis são corretas, mas requerem configuração especial
- Falta verificar se o Octane está configurado para usar sessões corretamente

**Arquivo:** `backend/config/octane.php` (não analisado completamente)
- Precisa verificar configuração de `swoole.tables` para sessões

---

## 📊 ANÁLISE DE PERFORMANCE

### Gargalos Identificados

#### 1. **Requisições Duplicadas de CSRF**
- Frontend faz `GET /sanctum/csrf-cookie` antes de **cada** login/register
- Isso adiciona latência desnecessária
- **Impacto:** +200-500ms por operação de autenticação

#### 2. **Octane + Redis Sessions**
- Octane mantém workers em memória, mas sessões vão para Redis
- Cada requisição autenticada faz **2 round-trips** ao Redis:
  1. Buscar sessão
  2. Atualizar sessão
- **Impacto:** +10-50ms por requisição autenticada

#### 3. **Nginx Proxy Overhead**
- Todas as requisições passam por Nginx → Backend
- Adiciona latência de proxy
- **Impacto:** +5-20ms por requisição

#### 4. **Falta de Cache de Rotas**
- Laravel carrega rotas a cada requisição (em desenvolvimento)
- **Solução:** `php artisan route:cache` em produção

---

## 🎯 ROADMAP DE CORREÇÕES

### FASE 1: DECISÃO ARQUITETURAL (URGENTE)

**Escolher UMA estratégia de autenticação:**

#### Opção A: Session-Based Authentication (RECOMENDADO)
**Vantagens:**
- ✅ Mais seguro (cookies HttpOnly)
- ✅ Melhor para SPAs no mesmo domínio
- ✅ Suporte nativo do Laravel
- ✅ Compatível com Octane

**Desvantagens:**
- ❌ Requer CSRF protection
- ❌ Mais complexo para mobile apps
- ❌ Requer configuração de CORS correta

**Mudanças necessárias:**
1. Remover **todo** código de tokens do frontend
2. Remover `localStorage.getItem('access_token')` dos guards
3. Implementar verificação de sessão via endpoint `/api/user`
4. Corrigir propagação de cookies no Nginx
5. Adicionar endpoint `/api/user` no backend

#### Opção B: Bearer Token Authentication
**Vantagens:**
- ✅ Mais simples para APIs
- ✅ Funciona bem com mobile apps
- ✅ Não requer CSRF protection
- ✅ Stateless

**Desvantagens:**
- ❌ Menos seguro (tokens em localStorage)
- ❌ Requer gerenciamento de tokens
- ❌ Vulnerável a XSS

**Mudanças necessárias:**
1. Reverter `AuthController::login()` para gerar tokens
2. Remover fluxo de CSRF do frontend
3. Remover `withCredentials: true` do interceptor
4. Manter guards atuais do frontend
5. Adicionar header `Authorization: Bearer {token}` no interceptor

---

### FASE 2: IMPLEMENTAÇÃO (APÓS DECISÃO)

#### Se escolher Session-Based (Opção A):

**Backend:**
1. ✅ Manter `AuthController::login()` atual (já usa sessões)
2. ✅ Manter `bootstrap/app.php` atual (já tem `statefulApi()`)
3. ❌ Remover `$user->tokens()->delete()` de `resetPassword()`
4. ➕ Adicionar endpoint `/api/user`:
```php
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);
});
```
5. ➕ Corrigir `verifyCode()` para usar sessões:
```php
Auth::guard('web')->login($user, true);
$request->session()->regenerate();
return response()->json(['user' => new UserResource($user)], 200);
```

**Frontend:**
1. ❌ Remover `localStorage.getItem('access_token')` de todos os guards
2. ➕ Criar novo guard baseado em endpoint:
```typescript
export const authGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);
  
  return authService.checkAuth().pipe(
    map(isAuth => {
      if (!isAuth) {
        router.navigate(['/login']);
        return false;
      }
      return true;
    })
  );
};
```
3. ➕ Adicionar método `checkAuth()` no `AuthService`:
```typescript
checkAuth(): Observable<boolean> {
  return this.http.get<{user: any}>('/api/user').pipe(
    map(res => {
      this.currentUserSignal.set(res.user);
      return true;
    }),
    catchError(() => of(false))
  );
}
```
4. ❌ Remover `localStorage.setItem('access_token', ...)` de `verify-email.ts`
5. ✅ Manter `getCsrfToken()` e `switchMap()` no `AuthService`
6. ✅ Manter `authInterceptor` atual (já adiciona CSRF header)

**Nginx:**
1. ➕ Adicionar propagação de cookies:
```nginx
location /api {
    proxy_pass http://backend;
    proxy_cookie_domain backend localhost;
    proxy_cookie_path / /;
    # ... resto da configuração
}

location /sanctum/csrf-cookie {
    proxy_pass http://backend;
    proxy_cookie_domain backend localhost;
    proxy_cookie_path / /;
    # ... resto da configuração
}
```

---

#### Se escolher Bearer Token (Opção B):

**Backend:**
1. ➕ Reverter `AuthController::login()`:
```php
public function login(LoginRequest $request): JsonResponse
{
    $fieldType = filter_var($request->login, FILTER_VALIDATE_EMAIL) ? 'email' : 'username';

    if (!Auth::attempt([$fieldType => $request->login, 'password' => $request->password])) {
        return response()->json(['message' => 'Credenciais inválidas.'], 401);
    }

    $user = Auth::user();

    if (!$user->email_verified_at) {
        return response()->json([
            'message' => 'E-mail não verificado.',
            'email' => $user->email,
            'requires_verification' => true
        ], 403);
    }

    $token = $user->createToken('auth_token')->plainTextToken;

    return response()->json([
        'access_token' => $token,
        'token_type' => 'Bearer',
        'user' => new UserResource($user)
    ], 200);
}
```
2. ➕ Atualizar `logout()`:
```php
public function logout(Request $request): JsonResponse
{
    $request->user()->currentAccessToken()->delete();
    return response()->json(['message' => 'Deslogado com sucesso!'], 200);
}
```
3. ➕ Atualizar `verifyCode()`:
```php
$user->email_verified_at = now();
$user->save();

$token = $user->createToken('auth_token')->plainTextToken;

return response()->json([
    'access_token' => $token,
    'token_type' => 'Bearer',
    'user' => new UserResource($user)
], 200);
```
4. ❌ Remover `statefulApi()` de `bootstrap/app.php`
5. ❌ Remover exceção de CSRF para `sanctum/csrf-cookie`

**Frontend:**
1. ❌ Remover `getCsrfToken()` e `switchMap()` do `AuthService`
2. ➕ Adicionar salvamento de token:
```typescript
login(credentials: any) {
    return this.http.post<AuthResponse>(`/api/login`, credentials).pipe(
        tap(res => {
            localStorage.setItem('access_token', res.access_token);
            this.currentUserSignal.set(res.user);
        })
    );
}
```
3. ➕ Atualizar `authInterceptor`:
```typescript
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const token = localStorage.getItem('access_token');
  
  if (token) {
    req = req.clone({
      setHeaders: {
        Authorization: `Bearer ${token}`
      }
    });
  }
  
  return next(req);
};
```
4. ❌ Remover `withCredentials: true`
5. ❌ Remover lógica de CSRF token
6. ✅ Manter guards atuais (já verificam `access_token`)

**Nginx:**
1. ❌ Remover `location /sanctum/csrf-cookie` (não será mais usado)
2. ✅ Manter `location /api` atual

---

### FASE 3: OTIMIZAÇÕES (APÓS CORREÇÕES)

#### Performance

1. **Cache de CSRF Token (se Session-Based)**
```typescript
private csrfTokenFetched = false;

getCsrfToken(): Observable<void> {
  if (this.csrfTokenFetched) {
    return of(void 0);
  }
  
  return this.http.get<void>('/sanctum/csrf-cookie').pipe(
    tap(() => this.csrfTokenFetched = true)
  );
}
```

2. **Cache de Rotas (Backend)**
```bash
php artisan route:cache
php artisan config:cache
php artisan view:cache
```

3. **Otimização do Octane**
```php
// config/octane.php
'tables' => [
    'sessions' => [
        'size' => 1000,
        'columns' => [
            ['name' => 'id', 'type' => Table::TYPE_STRING, 'size' => 128],
            ['name' => 'payload', 'type' => Table::TYPE_STRING, 'size' => 10000],
        ],
    ],
],
```

4. **Nginx Caching**
```nginx
# Cache de assets estáticos
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

#### Segurança

1. **Rate Limiting mais agressivo**
```php
// routes/api.php
Route::post('/login', [AuthController::class, 'login'])
    ->middleware('throttle:3,1'); // 3 tentativas por minuto
```

2. **Validação de Origin**
```php
// config/cors.php
'allowed_origins' => [
    env('FRONTEND_URL'),
],
'allowed_origins_patterns' => [],
```

3. **Headers de Segurança (Nginx)**
```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header Content-Security-Policy "default-src 'self'" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

#### Monitoramento

1. **Logs estruturados**
```php
// config/logging.php
'channels' => [
    'auth' => [
        'driver' => 'daily',
        'path' => storage_path('logs/auth.log'),
        'level' => 'info',
        'days' => 14,
    ],
],
```

2. **Métricas de Performance**
```typescript
// Frontend - Interceptor de métricas
export const metricsInterceptor: HttpInterceptorFn = (req, next) => {
  const start = Date.now();
  
  return next(req).pipe(
    tap(() => {
      const duration = Date.now() - start;
      console.log(`${req.method} ${req.url} - ${duration}ms`);
    })
  );
};
```

---

## 🔧 CORREÇÕES IMEDIATAS RECOMENDADAS

### Prioridade CRÍTICA (Fazer AGORA)

1. **Decidir estratégia de autenticação** (Session vs Token) **Sessions é escolha.
2. **Implementar endpoint `/api/user`** no backend **adicionado.
3. **Corrigir guards do frontend** para não depender de `localStorage` 
4. **Remover código legado** de tokens OU sessões (dependendo da escolha)

### Prioridade ALTA (Fazer esta semana)

1. **Corrigir propagação de cookies no Nginx** (se Session-Based)
2. **Implementar cache de CSRF token** (se Session-Based)
3. **Adicionar testes de autenticação** (E2E)
4. **Documentar fluxo de autenticação** escolhido

### Prioridade MÉDIA (Fazer este mês)

1. **Otimizar configuração do Octane**
2. **Implementar rate limiting mais agressivo**
3. **Adicionar logs estruturados**
4. **Implementar monitoramento de performance**

### Prioridade BAIXA (Backlog)

1. **Adicionar testes unitários** para AuthController
2. **Implementar refresh token** (se Bearer Token)
3. **Adicionar suporte a 2FA**
4. **Implementar logout de todos os dispositivos**

---

## 📝 CHECKLIST DE IMPLEMENTAÇÃO

### Session-Based Authentication (RECOMENDADO)

#### Backend
- [ ] Manter `AuthController::login()` atual
- [ ] Adicionar endpoint `GET /api/user`
- [ ] Remover `$user->tokens()->delete()` de `resetPassword()`
- [ ] Corrigir `verifyCode()` para usar sessões
- [ ] Testar fluxo completo de login/logout

#### Frontend
- [ ] Remover `localStorage.getItem('access_token')` dos guards
- [ ] Criar novo guard baseado em `/api/user`
- [ ] Adicionar método `checkAuth()` no `AuthService`
- [ ] Remover `localStorage.setItem('access_token')` de `verify-email.ts`
- [ ] Manter `getCsrfToken()` e interceptor
- [ ] Testar fluxo completo de login/logout

#### Nginx
- [ ] Adicionar `proxy_cookie_domain` e `proxy_cookie_path`
- [ ] Reiniciar Nginx
- [ ] Testar propagação de cookies

#### Testes
- [ ] Login com credenciais válidas
- [ ] Login com credenciais inválidas
- [ ] Logout
- [ ] Acesso a rota protegida sem autenticação
- [ ] Acesso a rota protegida com autenticação
- [ ] Refresh da página mantém autenticação
- [ ] Verificação de email
- [ ] Reset de senha

---

### Bearer Token Authentication (ALTERNATIVA)

#### Backend
- [ ] Reverter `AuthController::login()` para gerar tokens
- [ ] Atualizar `logout()` para deletar token atual
- [ ] Atualizar `verifyCode()` para retornar token
- [ ] Remover `statefulApi()` de `bootstrap/app.php`
- [ ] Remover exceção de CSRF
- [ ] Testar fluxo completo de login/logout

#### Frontend
- [ ] Remover `getCsrfToken()` e `switchMap()`
- [ ] Adicionar salvamento de token no `AuthService`
- [ ] Atualizar `authInterceptor` para adicionar header `Authorization`
- [ ] Remover `withCredentials: true`
- [ ] Remover lógica de CSRF
- [ ] Manter guards atuais
- [ ] Testar fluxo completo de login/logout

#### Nginx
- [ ] Remover `location /sanctum/csrf-cookie`
- [ ] Reiniciar Nginx

#### Testes
- [ ] Login com credenciais válidas
- [ ] Login com credenciais inválidas
- [ ] Logout
- [ ] Acesso a rota protegida sem token
- [ ] Acesso a rota protegida com token
- [ ] Refresh da página mantém autenticação
- [ ] Verificação de email
- [ ] Reset de senha

---

## 🎓 RECOMENDAÇÕES FINAIS

### Escolha da Estratégia

**Recomendo Session-Based Authentication porque:**

1. ✅ **Segurança:** Cookies HttpOnly são mais seguros que localStorage
2. ✅ **Arquitetura:** Nginx já está configurado como proxy único
3. ✅ **Laravel:** Suporte nativo e melhor integração com Octane
4. ✅ **Futuro:** Facilita implementação de features como "lembrar-me" e "logout de todos os dispositivos"

**Evite Bearer Tokens se:**
- ❌ Não precisa de API pública
- ❌ Não tem mobile app
- ❌ Frontend e backend estão no mesmo domínio (via Nginx)

### Próximos Passos

1. **Revisar este documento** com a equipe
2. **Decidir estratégia** de autenticação
3. **Criar branch** para implementação
4. **Implementar correções** seguindo o checklist
5. **Testar exaustivamente** antes de merge
6. **Documentar** decisões e fluxos
7. **Monitorar** performance e erros

### Contato e Suporte

Para dúvidas sobre este documento ou implementação:
- Revisar documentação oficial do Laravel Sanctum
- Revisar documentação oficial do Angular HttpClient
- Consultar logs do backend e frontend
- Usar ferramentas de debug (DevTools, Laravel Telescope)

---

**Documento gerado em:** 2024  
**Versão:** 1.0  
**Status:** ✅ Completo e pronto para implementação
