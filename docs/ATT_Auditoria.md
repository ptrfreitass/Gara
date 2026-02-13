
Deep Dive Diagnostic Report: Stateful Authentication Collapse Analysis
Executive Summary
Your stack represents a high-performance architecture with multiple state management layers (Browser → Nginx → Octane → Redis). The 419/403 cascade indicates a state synchronization breakdown across these boundaries. The root cause is likely a multi-layer desynchronization where CSRF tokens, session identifiers, and cookie lifecycles are misaligned between stateless proxies, stateful workers, and aggressive client-side caching.

1. Infrastructure Layer Diagnosis (Nginx & Docker Network)
Request Flow Analysis: Browser → Nginx → Octane → Redis
Critical Failure Points:

A. Nginx Proxy Header Stripping

Set-Cookie Path Corruption: When Nginx proxies to http://backend:9000, cookies set with Domain=localhost or Path=/api may not propagate correctly if Nginx doesn't preserve the original Host header. The browser receives cookies with mismatched domain/path attributes.

CORS Preflight Poisoning: If Nginx doesn't forward Origin headers correctly, Laravel's CORS middleware (HandleCors) will reject preflight OPTIONS requests. Subsequent POST/PUT/DELETE requests fail silently because the browser never received CORS approval.

X-XSRF-TOKEN Loss: Angular sends CSRF tokens via X-XSRF-TOKEN header. If Nginx strips custom headers (common in default configs), Laravel never receives the token, triggering 419 even when the token exists client-side.

X-Forwarded-For/X-Real-IP Mismatch: Octane's session fingerprinting (IP + User-Agent hash) may break if Nginx doesn't set X-Forwarded-For. Each request appears to come from a different "client" (Docker internal IPs like 172.18.0.x), invalidating sessions.

correção: 

default.conf = 
location /api = 
proxy_set_header Host $host;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $host;



B. Docker Network DNS Resolution

Service Name vs. Localhost Confusion: If your Angular app makes requests to http://localhost:8000 but Nginx proxies to http://backend:9000, cookies set by Laravel with SESSION_DOMAIN=localhost won't match the browser's perception of the domain. The browser sees localhost:8000, but the cookie is scoped to localhost:9000 or just localhost without port specificity.
C. SameSite & Secure Flag Violations

SameSite=Lax in Development: Modern browsers (Chrome 120+, Firefox 122+) enforce SameSite=Lax by default. If your Angular app is served from http://localhost:4200 and makes requests to http://localhost:8000, these are considered same-site. However, if Nginx rewrites the Referer or Origin, the browser may treat them as cross-site, blocking cookies.

Secure Flag Without HTTPS: If SESSION_SECURE_COOKIE=true in Laravel but you're running on HTTP, cookies are never sent by the browser. This is a silent failure—no console errors, just missing cookies.

D. Race Condition: Cookie Write vs. Read

Timing Issue: Nginx buffers responses. If Laravel sets a session cookie in Response A, but Nginx delays flushing it while Request B (from the same client) arrives, Request B won't have the cookie yet. Octane processes Request B with a "new" session, invalidating the CSRF token from Request A.
2. Backend Layer Diagnosis (Octane & Session Management)
Octane Request Lifecycle vs. FPM
Critical Differences:

A. Worker State Pollution (Memory Leak)

FPM: Each request spawns a fresh PHP process. Global state, static variables, and singletons are destroyed after the response.
Octane: Workers are long-lived. If your code (or a package) stores CSRF tokens, session IDs, or user data in static properties, they persist across requests. User A's token may "leak" into User B's request.
Example Scenario:

plaintext

Copy

Insert
B. Session Driver Misconfiguration

Redis Connection Pooling: Octane uses persistent Redis connections. If REDIS_CLIENT=phpredis but your Redis container restarts, Octane workers hold stale connections. Session reads fail silently, Laravel generates a new session, invalidating the CSRF token.

Session Serialization: Octane's Swoole runtime uses a different serialization mechanism than FPM. If you have custom session data (objects, closures), they may not deserialize correctly, causing session corruption.

C. CSRF Token Regeneration Logic

VerifyCsrfToken Middleware: On every state-changing request (POST/PUT/DELETE), Laravel regenerates the CSRF token after validation. If Octane's response is cached or buffered, the client receives the old token in the response but the new token is already active server-side. Next request: 419.
D. Session Locking & Concurrency

Redis Session Locking: Laravel locks sessions during write operations. If your Angular app fires multiple parallel requests (e.g., forkJoin with 5 simultaneous API calls), the first request locks the session. Requests 2-5 wait, timeout, or fail. When they retry, the CSRF token has changed.
E. Octane Warm/Flush Cycles

Graceful Reload: When you run php artisan octane:reload, workers finish current requests before restarting. If a worker is mid-request during reload, the session may be written to Redis but the response (with the new CSRF token) is lost. Client retries with the old token: 419.
3. Frontend Layer Diagnosis (Angular & Hydration)
Service Worker & Cookie Conflicts
A. PWA Cache Poisoning

Stale API Responses: If your Service Worker caches API responses (even with networkFirst strategy), it may serve a cached response containing an expired CSRF token in the HTML meta tag or JSON payload.

Cookie Exclusion: Service Workers cannot access cookies directly. If your SW intercepts a fetch() request and reconstructs it, cookies may not be attached. The request reaches Laravel without session cookies → new session → 419.

B. Angular HttpClient Interceptor Race

Token Extraction Timing: If you extract the CSRF token from a cookie (XSRF-TOKEN) in an HTTP interceptor, but the cookie hasn't been set yet (because the /sanctum/csrf-cookie response is still in-flight), the interceptor attaches null or an old token.
C. Hydration & SSR Conflicts

Server-Side Rendering: If you're using Angular Universal (SSR), the server-rendered HTML may contain a CSRF token from the server's session, but the client-side Angular app initializes with a different session (because the browser makes a new request to /sanctum/csrf-cookie). Token mismatch: 419.
D. Signal-Based Change Detection

Dead Request Scenario: Angular Signals optimize change detection, but if a Signal triggers an HTTP request before the previous request completes, you may send two requests with the same CSRF token. Laravel invalidates the token after the first request, the second fails with 419.
E. Browser Cookie Jar Corruption

Multiple Tabs: If a user opens your app in two tabs, both tabs share the same cookie jar. Tab A logs in → new session. Tab B still has the old session in memory (Angular service singleton). Tab B sends a request with the old CSRF token: 419.
4. Corrective Maintenance Roadmap (Sanitation & Restoration)
Phase 1: Nuclear Cache Purge (Order Matters)
Step 1.1: Client-Side Annihilation

Browser DevTools:

Clear all cookies for localhost (Application → Cookies → Delete All)
Clear Local Storage & Session Storage
Clear Cache Storage (Service Worker caches)
Unregister all Service Workers (Application → Service Workers → Unregister)
Hard Refresh: Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac) on every browser you've tested with.

Step 1.2: Docker Volume Destruction

shellscript

Copy

Insert
This destroys:

Redis data (sessions, cache, queues)
PostgreSQL data (if volume-mounted)
Any bind-mounted logs or temp files
Step 1.3: Laravel Cache Purge

shellscript

Copy

Run
Step 1.4: Redis Manual Flush (if not using -v flag)

shellscript

Copy

Run
Step 1.5: Angular Build Artifacts

shellscript

Copy

Run
Phase 2: Configuration Audit Checklist
Priority 1: Nginx Configuration Inspect nginx.conf or your site config:

 proxy_set_header Host $host; (preserves original domain)
 proxy_set_header X-Real-IP $remote_addr;
 proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
 proxy_set_header X-Forwarded-Proto $scheme;
 proxy_pass_request_headers on; (don't strip custom headers)
 proxy_cookie_domain and proxy_cookie_path directives (if rewriting cookies)
 CORS headers are NOT set in Nginx (let Laravel handle CORS)
Priority 2: Laravel .env

 SESSION_DRIVER=redis (not file or cookie)
 SESSION_DOMAIN=localhost (or null for automatic detection)
 SESSION_SECURE_COOKIE=false (unless using HTTPS)
 SESSION_SAME_SITE=lax (not strict or none)
 SANCTUM_STATEFUL_DOMAINS=localhost:4200,localhost:8000 (include all ports)
 REDIS_CLIENT=phpredis (faster than predis for Octane)
 OCTANE_SERVER=swoole (confirm Swoole is installed)
 SESSION_LIFETIME=120 (reasonable timeout)
Priority 3: Laravel config/cors.php

 'paths' => ['api/*', 'sanctum/csrf-cookie']
 'allowed_origins' => ['http://localhost:4200'] (exact match, no wildcards in dev)
 'supports_credentials' => true (critical for cookies)
 'exposed_headers' => ['X-XSRF-TOKEN']
Priority 4: Laravel config/session.php

 'driver' => env('SESSION_DRIVER', 'redis')
 'connection' => 'default' (matches config/database.php Redis connection)
 'lottery' => [2, 100] (session garbage collection)
 'http_only' => true (prevent XSS)
 'same_site' => 'lax'
Priority 5: Angular environment.ts

 apiUrl: 'http://localhost:8000' (matches Nginx exposed port)
 HttpClient configured with withCredentials: true globally or per-request
Priority 6: Angular app.config.ts (or main.ts)

 provideHttpClient(withInterceptors([...]), withXsrfConfiguration({ cookieName: 'XSRF-TOKEN', headerName: 'X-XSRF-TOKEN' }))
Priority 7: Docker Compose docker-compose.yml

 Backend service exposes port 9000 internally, Nginx proxies to it
 Nginx exposes port 8000 to host
 Redis service uses redis:alpine image with command: redis-server --appendonly yes (persistence)
 All services on same network (e.g., app-network)
Phase 3: Validation Protocol (Sequential Testing)
Test 1: Isolated Backend Health

Stop Nginx and Angular
Access Laravel directly: curl -v http://localhost:9000/sanctum/csrf-cookie
Verify Set-Cookie header contains XSRF-TOKEN and laravel_session
Extract cookies, send authenticated request:
shellscript

Copy

Run
Expected: 200 OK (not 419)
Test 2: Nginx Proxy Integrity

Start Nginx, keep Angular stopped
Repeat Test 1 but via Nginx: curl -v http://localhost:8000/sanctum/csrf-cookie
Verify cookies are identical to Test 1
Check Nginx logs for header forwarding
Test 3: Angular Integration

Start Angular dev server (ng serve)
Open DevTools → Network → Preserve Log
Navigate to app, trigger login
Inspect /sanctum/csrf-cookie request:
Response has Set-Cookie
Subsequent requests include Cookie and X-XSRF-TOKEN headers
If cookies are missing, check withCredentials: true in HttpClient
Test 4: Octane Worker Isolation

Enable Octane debug mode: OCTANE_WATCH_PATHS=app,config,routes
Add logging to VerifyCsrfToken middleware:
php

Copy

Insert
Trigger 419 error, check logs for token mismatch
If session_token changes between requests, suspect worker state pollution
Test 5: Redis Session Persistence

Login successfully
Restart Redis container: docker restart <redis-container>
Make authenticated request
Expected: 401 Unauthorized (session lost, not 419)
If 419, Redis persistence is broken (check --appendonly yes)
Test 6: Service Worker Bypass

Unregister Service Worker in DevTools
Hard refresh
Test authentication flow
If errors disappear, Service Worker is caching stale responses
Root Cause Hypothesis Matrix
Symptom	Probable Cause	Validation Test
419 on first request after login	Nginx stripping X-XSRF-TOKEN	Test 2 (check Nginx logs)
419 intermittently	Octane worker state pollution	Test 4 (check token logs)
403 on CORS preflight	supports_credentials not true	Test 3 (check OPTIONS response)
Cookies not sent by browser	Secure flag on HTTP	Test 1 (check Set-Cookie attributes)
419 after Redis restart	Session not persisted	Test 5 (restart Redis)
419 only in production build	Service Worker caching	Test 6 (unregister SW)
Critical Questions for Manual Inspection
Nginx: Does your config have proxy_pass http://backend:9000; or proxy_pass http://localhost:9000;? (Should be service name, not localhost)

Laravel: Do you have any custom middleware that modifies $request->session() or $request->cookie()?

Octane: Are you using any packages with static properties (e.g., old versions of Laravel Debugbar, Telescope)?

Angular: Do you have multiple HTTP interceptors? Order matters—CSRF interceptor must run after cookie is set.

Redis: Is your Redis container configured with maxmemory-policy allkeys-lru? This evicts sessions under memory pressure.

Docker: Are you using network_mode: host? This breaks service name resolution.

Next Steps
Once you've completed the audit checklist and validation tests, report back with:

Which tests passed/failed
Nginx config snippet (proxy block)
Laravel .env (sanitized)
Angular HTTP interceptor code
Docker Compose network configuration
This will allow surgical code-level fixes rather than shotgun debugging.