# Plan: SisVisa Admin Console (Phase 1)

## Track A — Backend (sisvisa-api)

Path base: `/Users/kleitonrocha/Development/sisvisa/sisvisa-api/`

### A.1 Model + Migration
- [A1.1] `src/database/migrations/20260508-create-feature-flags.js` — idempotente (queryInterface.describeTable → catch → createTable). up + down.
- [A1.2] `src/database/migrations/20260508-add-last-login-at-usuarios.js` — idempotente addColumn. up + down.
- [A1.3] `src/models/feature-flags.js` — Sequelize model padrão (segue `usuarios.js`).
- [A1.4] Ajuste em `src/models/usuarios.js` — adicionar `last_login_at` field.

### A.2 Repositories
- [A2.1] `src/repositories/admin-dashboard-repository.js` — funções `getTotaisAdmin()`, `getByFiscal(period)`, `getUltimasAcoes(limit)`.
- [A2.2] `src/repositories/professionals-repository.js` — `listProfessionals(period)`, `getTimeline(matricula, limit, before)`.
- [A2.3] `src/repositories/audit-repository.js` — `queryAudit({table_name, operation, user_id, from, to}, page, limit)`.
- [A2.4] `src/repositories/feature-flags-repository.js` — CRUD básico + `toggleByKey(key)`.

### A.3 Validators (Joi)
- [A3.1] `src/v2/validators/admin-schemas.js` — schemas:
  - `featureFlagCreateSchema`: `{ key (^[a-z0-9_-]+$), description, enabled, rollout_percentage (0-100), metadata }`
  - `featureFlagUpdateSchema`: idem sem key
  - `auditQuerySchema`: `{ table_name?, operation? (CREATE|UPDATE|DELETE), user_id? (int), from? (iso), to? (iso), page (default 1), limit (max 100, default 20) }`
  - `professionalsPeriodSchema`: `{ period (1-365, default 30) }`
  - `resetPasswordSchema`: `{ send_email (bool, default true) }`

### A.4 Controllers
- [A4.1] `src/v2/controllers/admin-dashboard-controller.js` — `getAdminDashboard(req, res)` agrega totais+by_fiscal+ultimas. Cache 60s via `withCache`.
- [A4.2] `src/v2/controllers/admin-professionals-controller.js` — `listProfessionals`, `getProfessionalTimeline`.
- [A4.3] `src/v2/controllers/admin-audit-controller.js` — `queryAudit` com paginação `ApiResponse.paginated`.
- [A4.4] `src/v2/controllers/admin-feature-flags-controller.js` — CRUD: `list`, `getByKey`, `create`, `update`, `toggle`, `remove`.
- [A4.5] `src/v2/controllers/admin-users-controller.js` — `resetPassword(matricula)` gera senha temporária via crypto, hash bcrypt, salva em usuarios, envia email via nodemailer (`src/services/email/`).

### A.5 Routes
- [A5.1] `src/v2/routes/admin-routes.js` — Router com `verifyToken` + `isGerente` aplicado uma vez via `router.use`. Sub-rotas:
  - `GET /dashboard` (readRateLimit, asyncHandler getAdminDashboard)
  - `GET /professionals` (readRateLimit, validate(professionalsPeriodSchema, 'query'), listProfessionals)
  - `GET /professionals/:matricula/timeline` (readRateLimit, validateMatricula, getProfessionalTimeline)
  - `GET /audit` (readRateLimit, validate(auditQuerySchema, 'query'), queryAudit)
  - `GET /feature-flags` (readRateLimit, listFlags)
  - `GET /feature-flags/:key` (readRateLimit, getFlag)
  - `POST /feature-flags` (writeRateLimit, validate(featureFlagCreateSchema), createFlag)
  - `PUT /feature-flags/:key` (writeRateLimit, validate(featureFlagUpdateSchema), updateFlag)
  - `PATCH /feature-flags/:key/toggle` (writeRateLimit, toggleFlag)
  - `DELETE /feature-flags/:key` (criticalRateLimit, removeFlag)
  - `POST /users/:matricula/reset-password` (criticalRateLimit, validateMatricula, validate(resetPasswordSchema), resetPassword)
- [A5.2] `src/v2/routes/index.js` — adicionar `import adminRoutes from './admin-routes.js'` + `router.use('/admin', adminRoutes)` antes de notFoundHandler.
- [A5.3] Ajuste em `src/v2/controllers/user-controller.js` `loginUser` — atualizar `last_login_at = NOW()` ao gerar JWT bem-sucedido.

### A.6 Middleware ajuste
- [A6.1] Confirmar `isGerente` está exportado em `src/middlewares/authenticate-service.js`. Já está.

### A.7 Build + sanity
- [A7.1] `npm run build` deve passar sem erro
- [A7.2] `npx eslint src/v2/controllers/admin-* src/v2/routes/admin-* src/v2/validators/admin-*` deve passar

## Track B — Frontend (sisvisa_web)

Path base: `/Users/kleitonrocha/Development/sisvisa/sisvisa_web/`

### B.1 Models (interfaces)
- [B1.1] `src/models/AdminDashboard.ts`, `Professional.ts`, `FeatureFlag.ts`, `AuditEntry.ts`, `AdminUser.ts`.

### B.2 Services
- [B2.1] `src/app/services/admin/admin-dashboard.service.ts` — `getDashboard()`.
- [B2.2] `src/app/services/admin/professionals.service.ts` — `list(period)`, `timeline(matricula, limit, before)`.
- [B2.3] `src/app/services/admin/feature-flags.service.ts` — `list()`, `get(key)`, `create(payload)`, `update(key, payload)`, `toggle(key)`, `remove(key)`.
- [B2.4] `src/app/services/admin/users-admin.service.ts` — usa `/v2/users` existente + `resetPassword(matricula)`.
- [B2.5] `src/app/services/admin/audit.service.ts` — `query(filters, page, limit)`.

Endpoints: `${environment._baseUrl}/v2/admin/...`. Usa HttpClient (já injetado via TokenInterceptorService).

### B.3 Guard
- [B3.1] `src/app/guards/admin.guard.ts` — CanActivate, decodifica JWT via JwtHelperService, checa `nivel_acesso === 'gerente'`, redirect `/home` se não.

### B.4 Components (presenter/features/admin/)

Cada componente: `.ts`, `.html`, `.scss`. Padrão Material 9 + PrimeNG TableModule onde aplicável.

- [B4.1] `admin-dashboard/admin-dashboard.component.*` — 4 cards (totais), tabela by_fiscal (PrimeNG p-table), lista últimas ações (timeline simples).
- [B4.2] `professionals/lista-professionals.component.*` — p-table com columns: matrícula, nome, last_action_at, termos_count, licencas_count, denuncias_count, ações (botão Timeline). Filtro por período (mat-select 7/30/90 dias).
- [B4.3] `professionals/timeline-professional.component.*` — header com dados do user, lista cronológica de audit_logs filtrada por user. Botão "Carregar mais".
- [B4.4] `feature-flags/lista-feature-flags.component.*` — p-table: key, description, enabled (mat-slide-toggle inline), rollout_percentage, ações (editar/excluir). Botão "Nova flag".
- [B4.5] `feature-flags/cadastro-feature-flag.component.*` — Reactive form: key (disabled em edit), description, enabled, rollout_percentage (slider 0-100), metadata (JSON textarea).
- [B4.6] `users-admin/lista-users.component.*` — p-table: matrícula, nome, nivel_acesso, is_enabled (toggle), ações (editar/reset-senha/desativar).
- [B4.7] `users-admin/cadastro-user.component.*` — form: matricula, nome, nivel_acesso (mat-select), is_enabled (checkbox). Ao criar: mostra senha temp gerada server-side.
- [B4.8] `audit/audit-log.component.*` — filtros (table_name, operation, user_id matricula, from, to date pickers), p-table paginado, dialog para ver `old_values`/`new_values` JSON.

### B.5 Menu
- [B5.1] Editar `src/app/components/menu/menu.component.*` — adicionar grupo "Admin" com sub-itens (Dashboard, Profissionais, Feature Flags, Usuários, Auditoria). Visível apenas se `nivel_acesso === 'gerente'`.

### B.6 Module wiring
- [B6.1] `src/app/app.module.ts` — imports + declarations para 8 components novos + 5 services + AdminGuard. Adicionar 8 rotas no `appRoute`. Imports adicionais: `MatSlideToggleModule`, `MatSliderModule`, `MatDialogModule`, `MatDatepickerModule`, `MatNativeDateModule`, `MatTabsModule` (se ainda não importado).

### B.7 Build + lint
- [B7.1] `npm run build` deve passar (NODE_OPTIONS já injetado)
- [B7.2] `npm run lint` deve passar

## Track C — QA & Validation

Após Tracks A+B:
- [C.1] Backend: `cd sisvisa-api && npm run build && npx eslint src/v2/controllers/admin-* src/v2/routes/admin-* src/v2/validators/admin-* src/repositories/admin-* src/repositories/professionals-* src/repositories/audit-* src/repositories/feature-flags-*`
- [C.2] Frontend: `cd sisvisa_web && npm run build`
- [C.3] Smoke teste manual (instruções no entregável final).
