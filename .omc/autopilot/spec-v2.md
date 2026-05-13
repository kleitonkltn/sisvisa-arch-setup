# Spec v2: Force-Change Password + Email Verification + TOTP 2FA

## Goals
1. **Email** — campo opcional + dupla verificação (link clicável **e** OTP 6 dígitos)
2. **Force change password** — usuário precisa trocar senha antes de acessar APIs em casos específicos
3. **TOTP 2FA opt-in** — Google Authenticator + 8 backup codes bcrypt single-use

## Schema

### Migration A: `usuarios` adicionar colunas (idempotente, todas nullable)
```
email VARCHAR(120) NULL                    -- opcional inicialmente
email_verified_at TIMESTAMP NULL
must_change_password BOOLEAN NOT NULL DEFAULT false
password_changed_at TIMESTAMP NULL
totp_enabled BOOLEAN NOT NULL DEFAULT false
totp_secret VARCHAR(255) NULL              -- base32 string (otplib)
totp_confirmed_at TIMESTAMP NULL
```
Index: `email` (único parcial onde NOT NULL — usar `where { email: { ne: null } }` no Sequelize index ou skip uniqueness por enquanto).

### Migration B: `email_verification_tokens` (nova)
```
id UUID PK
user_matricula INTEGER FK usuarios(matricula) ON DELETE CASCADE
token_hash VARCHAR(255) NOT NULL    -- bcrypt do link token
otp_code_hash VARCHAR(255) NOT NULL -- bcrypt do OTP 6 dígitos
expires_at TIMESTAMP NOT NULL
consumed_at TIMESTAMP NULL
created_at TIMESTAMP DEFAULT NOW()
```
Index: `user_matricula`, `expires_at`.

### Migration C: `user_backup_codes` (nova)
```
id UUID PK
user_matricula INTEGER FK usuarios(matricula) ON DELETE CASCADE
code_hash VARCHAR(255) NOT NULL  -- bcrypt
used_at TIMESTAMP NULL
created_at TIMESTAMP DEFAULT NOW()
```
Index: `user_matricula`.

## Endpoints

### Públicos (sem auth)

`POST /api/v2/users/auth/login`
- Mantém validador atual (matricula+password)
- Resposta tem 3 modos:
  - `totp_enabled=false` AND `must_change_password=false` AND `email_verified_at != null`:
    `{ token, user, must_change_password: false, email_verified: true, totp_required: false }`
  - `totp_enabled=false` AND (`must_change_password=true` OR email não verificado):
    Mesmo que acima, mas com flags `true`. Frontend redireciona.
  - `totp_enabled=true`:
    `{ pre_auth_token, user: {matricula}, totp_required: true }` — pre_auth_token JWT TTL 5min, claim `scope: 'pre-auth'`. Sem `token` final.

`POST /api/v2/users/auth/totp/verify`
- Body: `{ pre_auth_token, code | backup_code }`
- Valida pre_auth_token (HS256, claim scope=pre-auth)
- Se `code`: verifica via `authenticator.verify(secret, code)`
- Se `backup_code`: bcrypt compare contra user_backup_codes não-usados; marca `used_at`
- Retorna token full (mesmo formato do login sem 2FA), com `must_change_password` e `email_verified` flags

`GET /api/v2/users/email/verify-link?token=<jwt>`
- Token JWT TTL 24h, claim `scope='email-verify'`, payload `{matricula, jti}`
- Compare jti contra `email_verification_tokens.token_hash` (bcrypt)
- Se válido + não consumido: marca `usuarios.email_verified_at`, marca token consumed
- Retorna HTML simples ou redirect para frontend

### Autenticadas

`POST /api/v2/users/email/send-verification` (próprio user — exige `verifyToken`, não exige `isGerente`)
- Gera token JWT (jti aleatório) + OTP 6 dígitos
- Salva bcrypt(jti) e bcrypt(OTP) em `email_verification_tokens` com expiração 24h (link) — OTP curto 15min
- Envia email único contendo link clicável **e** código OTP
- Rate limit: 3/hora (writeRateLimit suficiente já?)

`POST /api/v2/users/email/verify-otp`
- Body: `{ otp }`
- Compara bcrypt contra OTPs ativos do user (não-consumidos, não-expirados)
- Se match: marca `email_verified_at`, consome token

`POST /api/v2/users/me/totp/setup`
- Gera secret base32 (`authenticator.generateSecret()`)
- Salva em `usuarios.totp_secret` (`totp_enabled` permanece false até confirm)
- Retorna `{ secret_base32, otpauth_url, qr_code_data_url }` (qrcode PNG dataURL)

`POST /api/v2/users/me/totp/confirm`
- Body: `{ code }`
- Verifica `authenticator.verify(secret, code)`
- Se OK: `totp_enabled=true`, `totp_confirmed_at=NOW()`, gera 8 backup codes
  - Format: `XXXX-XXXX` (10 chars hex). bcrypt cada um e salva em user_backup_codes
  - Retorna `{ backup_codes: ['ABCD-1234', ...] }` — **plaintext apenas nessa response**

`POST /api/v2/users/me/totp/disable`
- Body: `{ password }` — exige reauth com senha
- Verifica bcrypt password
- Se OK: `totp_enabled=false`, `totp_secret=null`, deleta backup codes

`POST /api/v2/users/me/totp/backup-codes/regenerate`
- Exige TOTP code no body para reauth
- Deleta backup codes anteriores, gera 8 novos. Retorna plaintext.

`PATCH /api/v2/users/:matricula/password` (já existe)
- Adicionar: ao trocar senha com sucesso, setar `password_changed_at=NOW()`, `must_change_password=false`

## Middleware: `requirePasswordChange` + `requireEmailVerified`

Em `src/v2/middlewares/auth-state-middleware.js`:
- `requirePasswordChange(req, res, next)`:
  - Lê `req.user.matricula` (do verifyToken)
  - Busca `must_change_password` do user
  - Se `true` AND rota não é uma das exceções → 403 com `{error: 'Troca de senha obrigatória', code: 'MUST_CHANGE_PASSWORD'}`
- `requireEmailVerified(req, res, next)`:
  - Análogo: 403 com `code: 'EMAIL_NOT_VERIFIED'` se `email_verified_at IS NULL` AND email não-null AND rota fora das exceções

**Exceções (rotas onde middlewares NÃO bloqueiam):**
- `PATCH /users/:matricula/password`
- `POST /users/email/send-verification`
- `POST /users/email/verify-otp`
- `GET /users/email/verify-link`
- `POST /users/auth/totp/verify` (já é pública mas para garantir)
- Qualquer endpoint do user "me" para obter status próprio

Aplicar `requirePasswordChange` e `requireEmailVerified` em `src/v2/routes/index.js` após `verifyToken` global, ou em cada router específico (admin-routes, license-routes, termo-routes, etc.) — preferir aplicar globalmente em `src/v2/routes/index.js` antes de mountar rotas de recurso.

## Force Trigger
- `must_change_password=true` quando:
  - Admin chama `POST /admin/users/:matricula/reset-password`
  - Admin cria user via `POST /v2/users` (controller marca flag automaticamente)

## Frontend (sisvisa_web)

### Login flow
Edit `src/app/services/autenticar.service.ts`:
- `login()` parseia response: se `totp_required` → guarda `pre_auth_token` em memória (não localStorage), navega `/login/totp`
- `verifyTotp(code)` → POST `/users/auth/totp/verify` → recebe token final → guarda em storage

### Componentes novos
- `presenter/features/authentication/login-totp/login-totp.component.{ts,html,css}` — input código + link "usar backup code"
- `presenter/features/authentication/verify-email/verify-email.component.{ts,html,css}` — mostra status, botão reenviar, input OTP
- `presenter/features/profile/totp-setup/totp-setup.component.{ts,html,css}` — botão Ativar 2FA → mostra QR + input confirm → mostra backup codes
- `presenter/features/profile/totp-disable/totp-disable.component.{ts,html,css}`
- `presenter/features/authentication/force-change-password/force-change-password.component.{ts,html,css}` — reusa lógica de alterar-senha mas sem voltar pra menu até trocar

### Guards
- `MustChangePasswordGuard` — se `must_change_password=true`, redirect `/forcar-troca-senha`
- `EmailVerifiedGuard` — se email não verificado, redirect `/verificar-email`
- Aplicar como `canActivateChild` no MainLayoutComponent (afeta tudo logado exceto `/forcar-troca-senha` e `/verificar-email`)

### Service
- `src/app/services/auth/auth-state.service.ts` — store das flags `mustChangePassword`, `emailVerified`, `totpEnabled` derivadas do login response. Observable.

## Dependências novas (backend)
- `otplib` ^12.0.1
- `qrcode` ^1.5.4

Frontend: nenhuma.

## Out of scope
- SMS 2FA
- Email change flow (mudar email já verificado pra outro)
- Password complexity policy (é responsabilidade do schema Joi atual)
- Session/device management
