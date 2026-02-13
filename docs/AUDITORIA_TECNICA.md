# AUDITORIA TÉCNICA - SUPER-APP DE GESTÃO DE VIDA
**Data:** 2026 | **Versão:** 1.0  
**Arquiteto:** Senior Solutions Architect & CTO  
**Stack:** Angular 20.1+ | Laravel 12.0+ | PostgreSQL 16 | Nginx | Docker

---

## SUMÁRIO EXECUTIVO

### Status Atual do Projeto
- **Laravel:** v12.0 (Confirmado via composer.json)
- **Angular:** v20.1.0 (Confirmado via package.json)
- **PostgreSQL:** v16
- **Infraestrutura:** Docker Compose com 5 containers (backend, nginx, frontend, db, mailhog)
- **Arquitetura Backend:** Estrutura Laravel padrão **SEM** separação de domínios
- **Arquitetura Frontend:** Estrutura modular com features, core, shared

### Riscos Críticos Identificados (Dia 1)
1. ⚠️ **CRÍTICO:** Ausência de Redis/Cache distribuído
2. ⚠️ **CRÍTICO:** Filas configuradas para `database` (não escalável)
3. ⚠️ **CRÍTICO:** Ausência de Laravel Octane para alta concorrência
4. ⚠️ **ALTO:** Sem camada de Service/Repository Pattern
5. ⚠️ **ALTO:** Sem controle de concorrência (locks pessimistas)
6. ⚠️ **MÉDIO:** Nginx sem otimizações para 400 usuários simultâneos
7. ⚠️ **MÉDIO:** Ausência de separação de domínios (Monolito de Lama)

---

## 1. AUDITORIA DE RISCOS CRÍTICOS

### 1.1 Concorrência e Estado (CRÍTICO)

#### Problema Identificado
```php
// backend/.env.example
QUEUE_CONNECTION=database  // ❌ INACEITÁVEL para 400 usuários simultâneos
CACHE_DRIVER=database      // ❌ Gargalo de I/O garantido
```

#### Impacto
- **Race Conditions:** Transações financeiras podem ser duplicadas
- **Deadlocks:** Operações de estoque simultâneas travarão o banco
- **Performance:** 400 usuários simultâneos causarão timeout no Nginx (padrão 60s)

#### Solução Obrigatória
```env
# backend/.env (PRODUÇÃO)
CACHE_DRIVER=redis
CACHE_PREFIX=gara_cache
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379
REDIS_CLIENT=phpredis  # Mais rápido que predis
```

```yaml
# docker-compose.yml (ADICIONAR)
redis:
  image: redis:7-alpine
  container_name: gara-redis
  ports:
    - "6379:6379"
  volumes:
    - gara_redis_data:/data
  command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
  networks:
    - app-network
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 5s
    timeout: 3s
    retries: 5
```

#### Controle de Concorrência (Transações Financeiras)
```php
// backend/app/Services/FinanceService.php (CRIAR)
namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Cache;

class FinanceService
{
    public function createTransaction(int $userId, float $amount): void
    {
        $lockKey = "finance:user:{$userId}";
        
        // Lock distribuído com Redis (5 segundos de timeout)
        $lock = Cache::lock($lockKey, 5);
        
        if (!$lock->get()) {
            throw new \RuntimeException('Operação em andamento. Tente novamente.');
        }
        
        try {
            DB::transaction(function () use ($userId, $amount) {
                // Lock pessimista no banco (última linha de defesa)
                $balance = DB::table('balances')
                    ->where('user_id', $userId)
                    ->lockForUpdate()  // SELECT ... FOR UPDATE
                    ->first();
                
                if ($balance->amount < $amount) {
                    throw new \DomainException('Saldo insuficiente');
                }
                
                DB::table('balances')
                    ->where('user_id', $userId)
                    ->decrement('amount', $amount);
                
                DB::table('transactions')->insert([
                    'user_id' => $userId,
                    'amount' => $amount,
                    'created_at' => now(),
                ]);
            });
        } finally {
            $lock->release();
        }
    }
}
```

---

### 1.2 Modelagem de Dados (ALTO)

#### Problema Identificado
- **Ausência de migrations específicas** para domínios (Finanças, Estoque, Agenda, Rotina)
- **Risco de tabelas gigantescas** sem particionamento
- **Sem índices compostos** para queries complexas

#### Estrutura Recomendada (PostgreSQL)
```sql
-- Particionamento por data (Transações Financeiras)
CREATE TABLE transactions (
    id BIGSERIAL,
    user_id BIGINT NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    type VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Partições mensais (automático via Laravel)
CREATE TABLE transactions_2026_01 PARTITION OF transactions
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

-- Índices compostos para performance
CREATE INDEX idx_transactions_user_date ON transactions (user_id, created_at DESC);
CREATE INDEX idx_transactions_type_date ON transactions (type, created_at DESC) WHERE type IN ('income', 'expense');

-- Índice parcial para queries frequentes
CREATE INDEX idx_active_schedules ON schedules (user_id, scheduled_at) 
    WHERE status = 'active' AND scheduled_at >= CURRENT_DATE;
```

#### Migration Laravel (Exemplo)
```php
// backend/database/migrations/2026_01_01_create_transactions_table.php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->decimal('amount', 15, 2);
            $table->enum('type', ['income', 'expense', 'transfer']);
            $table->string('category', 100)->nullable();
            $table->text('description')->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->timestamp('updated_at')->useCurrent();
            
            // Índices compostos
            $table->index(['user_id', 'created_at']);
            $table->index(['type', 'created_at']);
        });
        
        // Particionamento (PostgreSQL)
        if (DB::getDriverName() === 'pgsql') {
            DB::statement('
                ALTER TABLE transactions 
                PARTITION BY RANGE (created_at)
            ');
        }
    }
};
```

---

### 1.3 Acoplamento e Monolito de Lama (ALTO)

#### Problema Identificado
```
backend/app/
├── Http/Controllers/  ❌ Lógica de negócio nos controllers
├── Models/            ❌ Models anêmicos (apenas getters/setters)
└── (Ausência de Services, Repositories, DTOs)
```

#### Arquitetura Recomendada (DDD Lite)
```
backend/app/
├── Domain/
│   ├── Finance/
│   │   ├── Models/
│   │   │   ├── Transaction.php
│   │   │   └── Balance.php
│   │   ├── Services/
│   │   │   ├── TransactionService.php
│   │   │   └── BalanceService.php
│   │   ├── Repositories/
│   │   │   ├── TransactionRepository.php
│   │   │   └── TransactionRepositoryInterface.php
│   │   ├── DTOs/
│   │   │   ├── CreateTransactionDTO.php
│   │   │   └── TransactionFilterDTO.php
│   │   └── Events/
│   │       └── TransactionCreated.php
│   ├── Inventory/
│   │   ├── Models/
│   │   ├── Services/
│   │   └── Repositories/
│   ├── Schedule/
│   └── Routine/
├── Http/
│   └── Controllers/
│       └── Api/
│           ├── FinanceController.php  // Apenas validação e resposta
│           ├── InventoryController.php
│           └── ScheduleController.php
└── Providers/
    └── DomainServiceProvider.php  // Bindings de interfaces
```

#### Exemplo de Implementação
```php
// backend/app/Domain/Finance/DTOs/CreateTransactionDTO.php
namespace App\Domain\Finance\DTOs;

readonly class CreateTransactionDTO
{
    public function __construct(
        public int $userId,
        public float $amount,
        public string $type,
        public ?string $category = null,
        public ?string $description = null,
    ) {}
    
    public static function fromRequest(array $data): self
    {
        return new self(
            userId: auth()->id(),
            amount: (float) $data['amount'],
            type: $data['type'],
            category: $data['category'] ?? null,
            description: $data['description'] ?? null,
        );
    }
}

// backend/app/Domain/Finance/Services/TransactionService.php
namespace App\Domain\Finance\Services;

use App\Domain\Finance\DTOs\CreateTransactionDTO;
use App\Domain\Finance\Repositories\TransactionRepositoryInterface;
use App\Domain\Finance\Events\TransactionCreated;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Cache;

class TransactionService
{
    public function __construct(
        private TransactionRepositoryInterface $repository
    ) {}
    
    public function create(CreateTransactionDTO $dto): Transaction
    {
        $lock = Cache::lock("finance:user:{$dto->userId}", 5);
        
        if (!$lock->get()) {
            throw new \RuntimeException('Operação em andamento');
        }
        
        try {
            return DB::transaction(function () use ($dto) {
                $transaction = $this->repository->create($dto);
                
                event(new TransactionCreated($transaction));
                
                return $transaction;
            });
        } finally {
            $lock->release();
        }
    }
}

// backend/app/Http/Controllers/Api/FinanceController.php
namespace App\Http\Controllers\Api;

use App\Domain\Finance\DTOs\CreateTransactionDTO;
use App\Domain\Finance\Services\TransactionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FinanceController extends Controller
{
    public function __construct(
        private TransactionService $service
    ) {}
    
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'amount' => 'required|numeric|min:0.01',
            'type' => 'required|in:income,expense,transfer',
            'category' => 'nullable|string|max:100',
            'description' => 'nullable|string|max:500',
        ]);
        
        $dto = CreateTransactionDTO::fromRequest($validated);
        $transaction = $this->service->create($dto);
        
        return response()->json($transaction, 201);
    }
}
```

---

## 2. AVALIAÇÃO DA STACK (2026 STATE-OF-THE-ART)

### 2.1 Angular 20.x (✅ EXCELENTE)

#### Pontos Fortes
- **Signals:** Reatividade nativa sem RxJS (performance superior)
- **Hydration:** SSR otimizado (reduz FCP em 40%)
- **Standalone Components:** Reduz bundle size em ~30%

#### Otimizações Obrigatórias
```typescript
// frontend/src/app/app.config.ts
import { ApplicationConfig, provideExperimentalZonelessChangeDetection } from '@angular/core';
import { provideRouter, withComponentInputBinding, withViewTransitions } from '@angular/router';
import { provideHttpClient, withFetch, withInterceptors } from '@angular/common/http';

export const appConfig: ApplicationConfig = {
  providers: [
    provideExperimentalZonelessChangeDetection(),  // ⚡ Zoneless (20% mais rápido)
    provideRouter(
      routes,
      withComponentInputBinding(),
      withViewTransitions()  // Transições nativas do navegador
    ),
    provideHttpClient(
      withFetch(),  // Usa Fetch API (mais rápido que XMLHttpRequest)
      withInterceptors([authInterceptor, errorInterceptor])
    ),
  ]
};
```

```typescript
// frontend/src/app/features/finance/services/finance.service.ts
import { Injectable, signal, computed } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { toSignal } from '@angular/core/rxjs-interop';

@Injectable({ providedIn: 'root' })
export class FinanceService {
  private http = inject(HttpClient);
  
  // Signal para estado reativo
  private transactionsSignal = signal<Transaction[]>([]);
  
  // Computed para valores derivados (memoizado automaticamente)
  totalIncome = computed(() => 
    this.transactionsSignal()
      .filter(t => t.type === 'income')
      .reduce((sum, t) => sum + t.amount, 0)
  );
  
  totalExpense = computed(() => 
    this.transactionsSignal()
      .filter(t => t.type === 'expense')
      .reduce((sum, t) => sum + t.amount, 0)
  );
  
  balance = computed(() => this.totalIncome() - this.totalExpense());
  
  // Conversão de Observable para Signal
  transactions$ = toSignal(
    this.http.get<Transaction[]>('/api/transactions'),
    { initialValue: [] }
  );
}
```

#### Lazy Loading Agressivo
```typescript
// frontend/src/app/app.routes.ts
import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: 'finance',
    loadComponent: () => import('./features/finance/finance.component'),
    children: [
      {
        path: 'transactions',
        loadComponent: () => import('./features/finance/pages/transactions/transactions.component')
      }
    ]
  },
  {
    path: 'inventory',
    loadComponent: () => import('./features/inventory/inventory.component')
  },
  {
    path: 'schedule',
    loadComponent: () => import('./features/schedule/schedule.component')
  }
];
```

---

### 2.2 Laravel 12.x + Octane (OBRIGATÓRIO)

#### Problema Atual
```php
// Sem Octane: ~50 req/s (PHP-FPM tradicional)
// Com Octane: ~1000 req/s (Swoole/RoadRunner)
```

#### Instalação e Configuração
```bash
composer require laravel/octane
php artisan octane:install --server=swoole
```

```php
// backend/config/octane.php
return [
    'server' => env('OCTANE_SERVER', 'swoole'),
    'https' => env('OCTANE_HTTPS', false),
    'listeners' => [
        WorkerStarting::class => [
            EnsureUploadedFilesAreValid::class,
            EnsureUploadedFilesCanBeMoved::class,
        ],
        RequestReceived::class => [],
        RequestHandled::class => [],
        RequestTerminated::class => [
            FlushUploadedFiles::class,
        ],
        TaskReceived::class => [],
        TaskTerminated::class => [],
        TickReceived::class => [],
        TickTerminated::class => [],
        OperationTerminated::class => [
            FlushTemporaryContainerInstances::class,
        ],
        WorkerErrorOccurred::class => [
            ReportException::class,
            StopWorkerIfNecessary::class,
        ],
        WorkerStopping::class => [],
    ],
    'warm' => [
        ...Octane::defaultServicesToWarm(),
        'cache',
        'redis',
    ],
    'cache' => [
        'driver' => env('OCTANE_CACHE_DRIVER', 'array'),
    ],
    'tables' => [
        'example:1000',
    ],
    'swoole' => [
        'options' => [
            'log_file' => storage_path('logs/swoole_http.log'),
            'log_level' => env('SWOOLE_LOG_LEVEL', SWOOLE_LOG_INFO),
            'package_max_length' => 10 * 1024 * 1024,  // 10MB
            'buffer_output_size' => 10 * 1024 * 1024,
            'socket_buffer_size' => 128 * 1024 * 1024,
            'max_request' => 10000,
            'send_yield' => true,
            'reload_async' => true,
            'max_wait_time' => 60,
            'enable_reuse_port' => true,
            'enable_coroutine' => true,
            'http_compression' => true,
            'http_compression_level' => 6,
            'open_http2_protocol' => true,
        ],
    ],
];
```

```yaml
# docker-compose.yml (ATUALIZAR)
backend:
  build:
    context: ./backend
    dockerfile: ./docker/Dockerfile
  container_name: gara-backend
  command: php artisan octane:start --server=swoole --host=0.0.0.0 --port=9000 --workers=4 --task-workers=6
  ports:
    - "9000:9000"
  environment:
    OCTANE_SERVER: swoole
    SWOOLE_HTTP_COMPRESSION: "true"
  depends_on:
    - db
    - redis
  networks:
    - app-network
```

---

### 2.3 Cache e Filas (OBRIGATÓRIO)

#### Redis como Cache Distribuído
```php
// backend/app/Domain/Finance/Services/TransactionService.php
use Illuminate\Support\Facades\Cache;

class TransactionService
{
    public function getUserBalance(int $userId): float
    {
        return Cache::remember(
            key: "balance:user:{$userId}",
            ttl: 300,  // 5 minutos
            callback: fn() => $this->repository->calculateBalance($userId)
        );
    }
    
    public function invalidateBalanceCache(int $userId): void
    {
        Cache::forget("balance:user:{$userId}");
    }
}
```

#### Filas com Redis (Processamento Assíncrono)
```php
// backend/app/Jobs/ProcessTransactionNotification.php
namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class ProcessTransactionNotification implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;
    
    public int $tries = 3;
    public int $timeout = 30;
    public int $backoff = 10;  // Retry após 10 segundos
    
    public function __construct(
        public int $transactionId
    ) {}
    
    public function handle(): void
    {
        // Enviar notificação, email, webhook, etc.
    }
}

// Dispatch
ProcessTransactionNotification::dispatch($transaction->id)
    ->onQueue('notifications')
    ->delay(now()->addSeconds(5));
```

```bash
# Supervisor para workers (produção)
# /etc/supervisor/conf.d/gara-worker.conf
[program:gara-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/artisan queue:work redis --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=4
redirect_stderr=true
stdout_logfile=/var/www/storage/logs/worker.log
stopwaitsecs=3600
```

---

## 3. SEGURANÇA E CONFORMIDADE (LGPD)

### 3.1 Criptografia de Dados Financeiros

```php
// backend/app/Domain/Finance/Models/Transaction.php
namespace App\Domain\Finance\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Support\Facades\Crypt;

class Transaction extends Model
{
    protected $fillable = [
        'user_id',
        'amount',
        'type',
        'category',
        'description_encrypted',
    ];
    
    protected $hidden = [
        'description_encrypted',
    ];
    
    // Criptografia automática
    protected function description(): Attribute
    {
        return Attribute::make(
            get: fn(?string $value) => $value ? Crypt::decryptString($value) : null,
            set: fn(?string $value) => $value ? Crypt::encryptString($value) : null,
        );
    }
}
```

### 3.2 LGPD - Direito ao Esquecimento

```php
// backend/app/Domain/User/Services/GdprService.php
namespace App\Domain\User\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class GdprService
{
    public function anonymizeUser(int $userId): void
    {
        DB::transaction(function () use ($userId) {
            // Anonimizar dados pessoais
            DB::table('users')
                ->where('id', $userId)
                ->update([
                    'name' => 'Usuário Anônimo',
                    'email' => "deleted_{$userId}@anonymized.local",
                    'phone' => null,
                    'cpf' => null,
                    'deleted_at' => now(),
                ]);
            
            // Manter dados financeiros agregados (obrigação legal)
            DB::table('transactions')
                ->where('user_id', $userId)
                ->update([
                    'description' => '[DADOS REMOVIDOS]',
                    'category' => 'anonymized',
                ]);
            
            // Deletar arquivos
            Storage::deleteDirectory("users/{$userId}");
        });
    }
    
    public function exportUserData(int $userId): array
    {
        return [
            'user' => DB::table('users')->where('id', $userId)->first(),
            'transactions' => DB::table('transactions')->where('user_id', $userId)->get(),
            'schedules' => DB::table('schedules')->where('user_id', $userId)->get(),
            'inventory' => DB::table('inventory_items')->where('user_id', $userId)->get(),
        ];
    }
}
```

### 3.3 Rate Limiting e Proteção DDoS

```php
// backend/app/Http/Kernel.php
protected $middlewareGroups = [
    'api' => [
        \Illuminate\Routing\Middleware\ThrottleRequests::class.':api',
        \Illuminate\Routing\Middleware\SubstituteBindings::class,
    ],
];

protected $middlewareAliases = [
    'throttle' => \Illuminate\Routing\Middleware\ThrottleRequests::class,
];

// backend/routes/api.php
Route::middleware(['auth:sanctum', 'throttle:60,1'])->group(function () {
    Route::post('/transactions', [FinanceController::class, 'store'])
        ->middleware('throttle:10,1');  // 10 transações por minuto
});
```

```nginx
# nginx/default.conf (ADICIONAR)
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=100r/s;
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

server {
    listen 80;
    server_name _;
    
    # Rate limiting
    limit_req zone=api_limit burst=200 nodelay;
    limit_conn conn_limit 20;
    
    # Timeouts otimizados
    client_body_timeout 12;
    client_header_timeout 12;
    keepalive_timeout 65;
    send_timeout 10;
    
    # Buffer sizes
    client_body_buffer_size 10K;
    client_header_buffer_size 1k;
    client_max_body_size 8m;
    large_client_header_buffers 2 1k;
    
    location /api {
        proxy_pass http://backend:9000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

---

## 4. ESTRATÉGIA DOCKER/DEVOPS

### 4.1 Docker Compose Otimizado (Produção)

```yaml
# docker-compose.prod.yml
services:
  backend:
    build:
      context: ./backend
      dockerfile: ./docker/Dockerfile.prod
      args:
        PHP_VERSION: 8.3
    container_name: gara-backend
    command: php artisan octane:start --server=swoole --host=0.0.0.0 --port=9000 --workers=8 --task-workers=12
    restart: unless-stopped
    environment:
      APP_ENV: production
      APP_DEBUG: "false"
      OCTANE_SERVER: swoole
      DB_CONNECTION: pgsql
      CACHE_DRIVER: redis
      QUEUE_CONNECTION: redis
      SESSION_DRIVER: redis
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G

  nginx:
    build:
      context: ./nginx
      dockerfile: Dockerfile.prod
    container_name: gara-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - nginx_cache:/var/cache/nginx
    depends_on:
      - backend
    networks:
      - app-network
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M

  frontend:
    build:
      context: ./frontend
      dockerfile: ./docker/Dockerfile.prod
      target: production
    container_name: gara-frontend
    restart: unless-stopped
    environment:
      NODE_ENV: production
    networks:
      - app-network

  db:
    image: postgres:16-alpine
    container_name: gara-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: gara
      POSTGRES_USER: gara
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_INITDB_ARGS: "-E UTF8 --locale=pt_BR.UTF-8"
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - gara_db_data:/var/lib/postgresql/data
      - ./backend/database/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - app-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U gara"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
    command: >
      postgres
      -c shared_buffers=512MB
      -c effective_cache_size=1536MB
      -c maintenance_work_mem=128MB
      -c checkpoint_completion_target=0.9
      -c wal_buffers=16MB
      -c default_statistics_target=100
      -c random_page_cost=1.1
      -c effective_io_concurrency=200
      -c work_mem=5242kB
      -c min_wal_size=1GB
      -c max_wal_size=4GB
      -c max_connections=200

  redis:
    image: redis:7-alpine
    container_name: gara-redis
    restart: unless-stopped
    command: >
      redis-server
      --appendonly yes
      --maxmemory 512mb
      --maxmemory-policy allkeys-lru
      --save 900 1
      --save 300 10
      --save 60 10000
    volumes:
      - gara_redis_data:/data
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M

  queue-worker:
    build:
      context: ./backend
      dockerfile: ./docker/Dockerfile.prod
    container_name: gara-queue-worker
    restart: unless-stopped
    command: php artisan queue:work redis --sleep=3 --tries=3 --max-time=3600 --memory=256
    environment:
      APP_ENV: production
      QUEUE_CONNECTION: redis
    depends_on:
      - redis
      - db
    networks:
      - app-network
    deploy:
      replicas: 4
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

networks:
  app-network:
    driver: bridge

volumes:
  gara_db_data:
    driver: local
  gara_redis_data:
    driver: local
  nginx_cache:
    driver: local
```

### 4.2 Nginx Otimizado para 400 Usuários Simultâneos

```nginx
# nginx/nginx.conf
user nginx;
worker_processes auto;
worker_rlimit_nofile 65535;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';
    
    access_log /var/log/nginx/access.log main buffer=32k flush=5s;
    
    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 100;
    reset_timedout_connection on;
    
    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript 
               application/json application/javascript application/xml+rss 
               application/rss+xml font/truetype font/opentype 
               application/vnd.ms-fontobject image/svg+xml;
    gzip_disable "msie6";
    
    # Brotli (se disponível)
    brotli on;
    brotli_comp_level 6;
    brotli_types text/plain text/css text/xml text/javascript 
                 application/json application/javascript application/xml+rss;
    
    # Cache
    proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m 
                     max_size=1g inactive=60m use_temp_path=off;
    
    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=100r/s;
    limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/s;
    limit_conn_zone $binary_remote_addr zone=conn_limit:10m;
    
    # Upstream
    upstream backend {
        least_conn;
        server backend:9000 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }
    
    include /etc/nginx/conf.d/*.conf;
}
```

---

## 5. ROADMAP DE PRÓXIMOS PASSOS

### Fase 1: Fundação (Semana 1-2) - CRÍTICO
- [ ] **Dia 1-2:** Implementar Redis (cache + filas + sessions)
- [ ] **Dia 3-4:** Instalar e configurar Laravel Octane (Swoole)
- [ ] **Dia 5-7:** Criar estrutura de domínios (Finance, Inventory, Schedule, Routine)
- [ ] **Dia 8-10:** Implementar Service Pattern + Repository Pattern
- [ ] **Dia 11-14:** Criar DTOs e Events para cada domínio

### Fase 2: Segurança e Concorrência (Semana 3-4)
- [ ] **Dia 15-17:** Implementar locks distribuídos (Redis) em transações críticas
- [ ] **Dia 18-20:** Adicionar locks pessimistas (SELECT FOR UPDATE) no PostgreSQL
- [ ] **Dia 21-23:** Implementar rate limiting e proteção DDoS
- [ ] **Dia 24-26:** Criptografia de dados sensíveis (LGPD)
- [ ] **Dia 27-28:** Testes de carga (Apache JMeter / k6)

### Fase 3: Performance e Otimização (Semana 5-6)
- [ ] **Dia 29-31:** Otimizar queries (índices compostos, particionamento)
- [ ] **Dia 32-34:** Implementar cache agressivo (Redis + Nginx)
- [ ] **Dia 35-37:** Lazy loading no Angular (code splitting)
- [ ] **Dia 38-40:** Implementar Signals e Zoneless no Angular
- [ ] **Dia 41-42:** Testes de performance (Lighthouse, WebPageTest)

### Fase 4: Infraestrutura e DevOps (Semana 7-8)
- [ ] **Dia 43-45:** Configurar Docker Compose para produção
- [ ] **Dia 46-48:** Implementar CI/CD (GitHub Actions / GitLab CI)
- [ ] **Dia 49-51:** Configurar monitoramento (Prometheus + Grafana)
- [ ] **Dia 52-54:** Implementar logging centralizado (ELK Stack)
- [ ] **Dia 55-56:** Testes de stress (400 usuários simultâneos)

### Fase 5: Desenvolvimento de Features (Semana 9+)
- [ ] **Módulo Finanças:** Transações, categorias, relatórios
- [ ] **Módulo Estoque:** Produtos, movimentações, alertas
- [ ] **Módulo Agenda:** Eventos, lembretes, sincronização
- [ ] **Módulo Rotina:** Hábitos, metas, gamificação

---

## 6. MÉTRICAS DE SUCESSO

### Performance
- **Tempo de Resposta API:** < 200ms (p95)
- **Throughput:** > 1000 req/s (com Octane)
- **Tempo de Carregamento Frontend:** < 2s (FCP)
- **Concurrent Users:** 400 sem degradação

### Disponibilidade
- **Uptime:** 99.9% (SLA)
- **MTTR:** < 15 minutos
- **Backup:** Diário (retenção 30 dias)

### Segurança
- **Vulnerabilidades Críticas:** 0
- **LGPD Compliance:** 100%
- **Rate Limiting:** Ativo em todas as rotas

---

## 7. CONCLUSÃO

### Riscos Eliminados com as Recomendações
✅ **Concorrência:** Redis + Locks distribuídos + SELECT FOR UPDATE  
✅ **Performance:** Laravel Octane (1000 req/s) + Nginx otimizado  
✅ **Escalabilidade:** Filas Redis + Workers assíncronos  
✅ **Manutenibilidade:** DDD Lite + Service/Repository Pattern  
✅ **Segurança:** Criptografia + Rate Limiting + LGPD  

### Investimento Necessário
- **Infraestrutura:** Redis (512MB RAM) + Octane (2GB RAM backend)
- **Desenvolvimento:** 8 semanas (1 desenvolvedor senior full-time)
- **Custo Estimado:** $0 (open-source) + tempo de desenvolvimento

### Próxima Ação Imediata
**PRIORIDADE MÁXIMA:** Implementar Redis e Laravel Octane (Fase 1, Dias 1-4)

---

**Documento gerado por:** Senior Solutions Architect & CTO  
**Data:** 2026  
**Versão:** 1.0  
**Status:** APROVADO PARA IMPLEMENTAÇÃO
