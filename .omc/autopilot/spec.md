# Spec: SisVisa Admin Console (Phase 0)

## Goal
Estender admin web (sisvisa_web Angular 9) e backend (sisvisa-api v2) com:
1. Dashboard agregado de profissionais
2. Lista fiscais ativos + última atividade
3. Métricas por fiscal (termos / licenças / denúncias atendidas)
4. Timeline live de ações (polling 10s — sem WebSocket)
5. Audit log queryável
6. Feature flags (CRUD + toggle)
7. User management (CRUD + reset senha + papéis + auditoria já automática via audit_logs)

## Constraints
- Backend: sisvisa-api v2 (Node 22, Express, Sequelize, Joi, JWT). Migrations idempotentes (`describeTable` antes de `addColumn`/`createTable`). Heroku release phase roda automaticamente. Rotas em `/api/v2/admin/*`.
- Frontend: sisvisa_web Angular 9 (não atualize). Material 9 + PrimeNG 9. NODE_OPTIONS=--openssl-legacy-provider. Eager loading (sem lazy modules). Pattern existente: `presenter/features/{domain}/{cadastro|lista|visualizar}`.
- Auth: `verifyToken` + `isGerente` em todas as rotas admin (acesso restrito).
- Rate limit: readRateLimit em GETs, writeRateLimit em POST/PUT, criticalRateLimit em DELETE/reset-password.

## Endpoints (sisvisa-api v2)

### `GET /api/v2/admin/dashboard`
Resposta agregada do admin. Cache 60s (TTL menor que dashboard fiscal).
```json
{
  "totais": { "fiscais_ativos": 12, "termos_mes": 45, "licencas_pendentes": 28, "denuncias_abertas": 17 },
  "by_fiscal": [{ "matricula": 12345, "nome": "...", "termos": 5, "licencas": 3, "denuncias": 2 }],
  "ultimas_acoes": [{ "user_id": 12345, "operation": "CREATE", "table_name": "termos", "record_id": "789", "timestamp": "..." }]
}
```

### `GET /api/v2/admin/professionals`
Query: `?period=30` (dias). Retorna fiscais (`nivel_acesso IN ['fiscal','gerente']`) com:
- `last_login_at` (do JWT iat — derivado de audit_logs ou fallback para updatedAt usuario)
- `last_action_at` (max timestamp em audit_logs onde user_id = matricula)
- contadores: termos_count, licencas_count, denuncias_count no período

### `GET /api/v2/admin/professionals/:matricula/timeline`
Query: `?limit=50&before=<iso>`. Retorna ações de audit_logs do user.

### `GET /api/v2/admin/audit`
Query: `table_name`, `operation`, `user_id`, `from`, `to`, `page`, `limit`. Paginado via ApiResponse.paginated.

### `GET /api/v2/admin/feature-flags`
Lista todas. `GET /:key` busca uma. `POST /` cria. `PUT /:key` edita. `PATCH /:key/toggle` flip enabled. `DELETE /:key`.

### Users (já existem em `/api/v2/users` — admin reusa, adiciona):
- `POST /api/v2/admin/users/:matricula/reset-password` — gera senha temp, envia email via nodemailer, força change-password no próximo login.

## Schema novo

### Migration: `YYYYMMDD-create-feature-flags.js`
```sql
CREATE TABLE feature_flags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key VARCHAR(64) UNIQUE NOT NULL,
  description TEXT,
  enabled BOOLEAN NOT NULL DEFAULT false,
  rollout_percentage SMALLINT NOT NULL DEFAULT 0 CHECK (rollout_percentage BETWEEN 0 AND 100),
  metadata JSONB,
  created_by INTEGER REFERENCES usuarios(matricula),
  updated_by INTEGER REFERENCES usuarios(matricula),
  createdAt TIMESTAMP NOT NULL DEFAULT NOW(),
  updatedAt TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX feature_flags_enabled ON feature_flags(enabled);
```

Pattern idempotente: `describeTable('feature_flags').catch(() => createTable(...))`.

### Coluna nova em usuarios (opcional — se quisermos last_login_at explícito):
- `last_login_at TIMESTAMP NULL` — atualizado em `loginUser` controller.

## Frontend (sisvisa_web)

### Estrutura
```
src/app/presenter/features/admin/
├── admin-dashboard/
│   ├── admin-dashboard.component.ts/html/scss
├── professionals/
│   ├── lista-professionals.component.*  (tabela + filtros)
│   └── timeline-professional.component.* (drill-down)
├── feature-flags/
│   ├── lista-feature-flags.component.*  (toggle inline)
│   └── cadastro-feature-flag.component.* (form)
├── users-admin/
│   ├── lista-users.component.*  (CRUD + reset senha)
│   └── cadastro-user.component.*
└── audit/
    └── audit-log.component.* (filtros + tabela paginada)
```

### Services
```
src/app/services/admin/
├── admin-dashboard.service.ts
├── professionals.service.ts
├── feature-flags.service.ts
├── users-admin.service.ts
└── audit.service.ts
```
Pattern: HttpClient + environment._baseUrl, endpoints sob `/v2/admin/...`.

### Rotas (em app.module.ts appRoute)
Sob MainLayoutComponent + AuthGuard:
- `admin/dashboard` → AdminDashboardComponent
- `admin/profissionais` → ListaProfessionalsComponent
- `admin/profissionais/:matricula` → TimelineProfessionalComponent
- `admin/feature-flags` → ListaFeatureFlagsComponent
- `admin/feature-flags/novo` / `admin/feature-flags/:key` → CadastroFeatureFlagComponent
- `admin/usuarios` → ListaUsersComponent
- `admin/usuarios/novo` / `admin/usuarios/:matricula` → CadastroUserComponent
- `admin/audit` → AuditLogComponent

### Role guard frontend
Adicionar `AdminGuard` em `src/app/guards/admin.guard.ts` que checa `nivel_acesso === 'gerente'` no token. Aplicar em todas rotas admin via `canActivate: [AuthGuard, AdminGuard]`.

### Menu
Adicionar item "Admin" em `MenuComponent` visível apenas para gerente.

## Out of scope desta iteração
- WebSocket para timeline real-time (usar polling 10s)
- Export CSV de audit log (já existe `CsvExportButtonComponent` — reusar em futura iteração)
- 2FA / MFA
- Filtros avançados de audit por changed_fields JSON contains
