# 🚀 Roadmap de Desenvolvimento - Pergeco

## 📌 Visão Geral
Sistema de gestão financeira pessoal com foco em UX, gamificação e inteligência financeira.

**Stack Tecnológica:**
- Backend: Laravel 12 + PHP 8.2 + PostgreSQL 17
- Frontend: Angular 21 + TypeScript 5.8
- UI: Angular Material + Bootstrap 5
- Autenticação: Laravel Sanctum
- Containerização: Docker (Laravel Sail)

---

## 🎯 Sprint 0: Fundação do Projeto (Setup Inicial)

### Objetivos
Criar uma base sólida e bem documentada para o desenvolvimento.

### Tarefas Backend
- [x] Limpar estrutura Laravel atual
- [x] Configurar .env.example com todas as variáveis
- [x] Configurar CORS para comunicação com Angular
- [x] Configurar Laravel Sanctum
- [x] Criar migration inicial de Users
- [x] Configurar Docker Compose (Laravel Sail)
- [x] Testar conexão com PostgreSQL
- [x] Criar seeders básicos

### Tarefas Frontend
- [x] Limpar estrutura Angular atual
- [x] Configurar arquitetura modular
- [x] Configurar environment (dev/prod)
- [ ] Configurar proxy para API
- [ ] Instalar e configurar Angular Material
- [ ] Criar estrutura de pastas padronizada
- [ ] Configurar interceptors base
- [ ] Configurar guards base

### Documentação
- [ ] README.md principal
- [ ] README.md do Backend
- [ ] README.md do Frontend
- [ ] Guia de instalação
- [ ] Guia de contribuição
- [ ] Documentação da API (Postman/Swagger)

### Resultado Esperado
✅ Projeto rodando com Docker
✅ Frontend conectando com Backend
✅ Documentação completa
✅ Estrutura de pastas organizada

---

## 🔐 Sprint 1: Autenticação Completa

### Objetivos
Sistema de autenticação funcional do início ao fim.

### Backend
- [ ] Controller: AuthController (register, login, logout, me)
- [ ] Request: RegisterRequest (validação)
- [ ] Request: LoginRequest (validação)
- [ ] Resource: UserResource (serialização)
- [ ] Routes: api.php (rotas públicas e protegidas)
- [ ] Middleware: Sanctum auth
- [ ] Testes: AuthTest (Pest PHP)

### Frontend
- [ ] Service: AuthService (métodos de autenticação)
- [ ] Service: TokenService (gerenciamento de token)
- [ ] Guard: AuthGuard (proteção de rotas)
- [ ] Interceptor: AuthInterceptor (adicionar token)
- [ ] Interceptor: ErrorInterceptor (tratamento de erros)
- [ ] Component: LoginComponent
- [ ] Component: RegisterComponent
- [ ] Routes: Rotas públicas e protegidas

### Fluxo Completo
1. Usuário acessa /register
2. Preenche formulário (nome, email, senha)
3. Backend valida e cria usuário
4. Backend retorna token
5. Frontend armazena token (localStorage)
6. Usuário é redirecionado para /dashboard
7. Todas as requisições incluem token no header
8. Backend valida token em rotas protegidas

### Resultado Esperado
✅ Registro funcionando
✅ Login funcionando
✅ Logout funcionando
✅ Rotas protegidas funcionando
✅ Token sendo enviado automaticamente

---

## 🎨 Sprint 2: Layout Base e Navegação

### Objetivos
Criar a estrutura visual da aplicação.

### Componentes
- [ ] LayoutComponent (container principal)
- [ ] SidebarComponent (menu lateral expansível)
- [ ] HeaderComponent (barra superior)
- [ ] FooterComponent (rodapé)
- [ ] DashboardComponent (página inicial)

### Sidebar - Estrutura de Menu
```
📊 Dashboard
💰 Finanças (expansível ao hover)
   ├── ➕ Novo Registro
   ├── 📈 Previsão
   ├── 🏷️ Categorias
   └── 📜 Histórico
📊 Relatórios
⚙️ Configurações
👤 Perfil
🚪 Sair
```

### Features da Sidebar
- [ ] Expansão ao hover (desktop)
- [ ] Menu hamburguer (mobile)
- [ ] Submenu expansível
- [ ] Item ativo destacado
- [ ] Animações suaves
- [ ] Ícones do Angular Material

### Responsividade
- [ ] Desktop (>1024px): Sidebar fixa
- [ ] Tablet (768-1024px): Sidebar colapsável
- [ ] Mobile (<768px): Menu hamburguer

### Resultado Esperado
✅ Layout profissional
✅ Navegação intuitiva
✅ Sidebar funcionando perfeitamente
✅ Responsivo em todos os dispositivos

---

## 🔔 Sprint 3: Sistema de Feedback

### Objetivos
Criar sistema de comunicação com o usuário.

### Componentes
- [ ] ToastService (serviço global)
- [ ] LoadingService (controle de loading)
- [ ] LoadingInterceptor (loading automático)
- [ ] ErrorInterceptor (erros HTTP)

### Tipos de Toast
- ✅ Sucesso (verde)
- ⚠️ Aviso (amarelo)
- ❌ Erro (vermelho)
- ℹ️ Informação (azul)

### Loading
- [ ] Spinner global (requisições HTTP)
- [ ] Skeleton loaders (listas)
- [ ] Progress bar (uploads)

### Resultado Esperado
✅ Feedback visual em todas as ações
✅ Loading automático em requisições
✅ Erros tratados e exibidos
✅ UX profissional

---

## 🏷️ Sprint 4: CRUD de Categorias

### Objetivos
Primeira feature completa do sistema.

### Backend
- [ ] Migration: categories (id, name, icon, color, type, user_id)
- [ ] Model: Category
- [ ] Controller: CategoryController (CRUD completo)
- [ ] Request: CategoryRequest (validação)
- [ ] Resource: CategoryResource
- [ ] Seeder: Categorias padrão
- [ ] Routes: /api/categories

### Frontend
- [ ] Service: CategoryService
- [ ] Component: CategoryListComponent (listagem)
- [ ] Component: CategoryFormComponent (criar/editar)
- [ ] Component: CategoryCardComponent (card visual)
- [ ] Dialog: Confirmação de exclusão

### Categorias Padrão (Seeder)
**Receitas:**
- 💼 Salário
- 💰 Freelance
- 🎁 Presentes
- 📈 Investimentos

**Despesas:**
- 🏠 Moradia
- 🍔 Alimentação
- 🚗 Transporte
- 💊 Saúde
- 🎓 Educação
- 🎮 Lazer
- 👕 Vestuário
- 📱 Tecnologia

### Resultado Esperado
✅ CRUD completo funcionando
✅ Categorias padrão importadas
✅ Interface visual atraente
✅ Validações funcionando

---

## 💸 Sprint 5: Lançamentos Financeiros

### Objetivos
Core do sistema - registrar receitas e despesas.

### Backend
- [ ] Migration: transactions
- [ ] Model: Transaction
- [ ] Controller: TransactionController
- [ ] Request: TransactionRequest
- [ ] Resource: TransactionResource
- [ ] Filtros: data, categoria, tipo
- [ ] Paginação

### Frontend
- [ ] Service: TransactionService
- [ ] Component: TransactionFormComponent (multi-step)
- [ ] Component: TransactionListComponent
- [ ] Component: TransactionCardComponent
- [ ] Pipe: CurrencyBRL
- [ ] Filtros e busca

### Formulário Multi-Step
**Step 1:** Tipo (Receita/Despesa)
**Step 2:** Valor e Data
**Step 3:** Categoria
**Step 4:** Descrição (opcional)
**Step 5:** Confirmação

### Resultado Esperado
✅ Registrar receitas/despesas
✅ Listar lançamentos
✅ Filtrar por data/categoria
✅ Editar/excluir lançamentos

---

## 📊 Sprint 6: Dashboard Inicial

### Objetivos
Visão geral das finanças.

### Cards do Dashboard
- [ ] Saldo Total
- [ ] Receitas do Mês
- [ ] Despesas do Mês
- [ ] Economia do Mês

### Gráficos
- [ ] Gastos por Categoria (Pizza)
- [ ] Evolução Mensal (Linha)
- [ ] Receitas vs Despesas (Barra)

### Últimas Movimentações
- [ ] Lista das 5 últimas transações
- [ ] Link para ver todas

### Resultado Esperado
✅ Dashboard informativo
✅ Gráficos funcionais
✅ Visão rápida das finanças

---

## 📈 Próximas Sprints (Futuro)

### Sprint 7: Relatórios Avançados
### Sprint 8: Metas Financeiras
### Sprint 9: Diagnóstico Financeiro
### Sprint 10: Gamificação (Badges, Streaks)
### Sprint 11: Notificações e Alertas
### Sprint 12: Exportação de Dados
### Sprint 13: PWA e Modo Offline
### Sprint 14: Integração Bancária

---

## 📝 Convenções do Projeto

### Commits
```
feat: adiciona nova funcionalidade
fix: corrige bug
docs: atualiza documentação
style: formatação de código
refactor: refatoração
test: adiciona testes
chore: tarefas de manutenção
```

### Branches
- `main`: produção
- `develop`: desenvolvimento
- `feature/nome-da-feature`: novas features
- `fix/nome-do-bug`: correções

### Nomenclatura
**Backend (Laravel):**
- Controllers: `NomeController.php`
- Models: `Nome.php`
- Requests: `NomeRequest.php`
- Resources: `NomeResource.php`

**Frontend (Angular):**
- Components: `nome.component.ts`
- Services: `nome.service.ts`
- Guards: `nome.guard.ts`
- Interceptors: `nome.interceptor.ts`

---

## 🎯 Meta Final

Criar um sistema de gestão financeira:
- ✅ Profissional
- ✅ Intuitivo
- ✅ Completo
- ✅ Escalável
- ✅ Bem documentado
- ✅ Testado

**Prazo estimado:** 6-8 semanas (trabalhando consistentemente)

---

**Última atualização:** 2025
**Desenvolvedor:** Patrick
**Status:** 🚀 Em desenvolvimento
