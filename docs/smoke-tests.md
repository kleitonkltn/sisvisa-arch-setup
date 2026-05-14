# SisVisa — Runbook de Smoke Tests

Procedimentos manuais para validar fluxos críticos após deploy ou alterações relevantes.

## Pré-requisitos

- Backend rodando (`https://sis-visa-dev.herokuapp.com/api` em dev, prod no Heroku)
- Frontend web acessível (URL Firebase Hosting)
- App Flutter instalado em dispositivo Android com flavor `dev`
- Usuários de teste:
  - **master** — `nivel_acesso='master'` (criar/promover via psql se necessário)
  - **gerente** — `nivel_acesso='gerente'`
  - **fiscal** — `nivel_acesso='fiscal'`
  - **administrativo** — `nivel_acesso='administrativo'`

## 1. Login + token + sessão

**Web e Flutter:**
1. Login com credenciais válidas (matrícula + senha)
2. Verificar redirecionamento para home
3. Verificar JWT no localStorage (web) / secure storage (Flutter)
4. Verificar `last_login_at` atualizado em `usuarios`

**Falhas esperadas:**
- Senha errada → 401, mensagem clara
- Usuário com `is_enabled=false` → 401 "Usuário desativado"
- Sem rede → mensagem de erro de conexão

## 2. Fluxo obrigatório — alterar senha (first login)

**Pré-condição:** usuário com `must_change_password=true`

1. Login com matricula + senha temporária
2. Backend retorna token + flag `must_change_password=true`
3. Frontend redireciona para `/alterar-senha-obrigatoria`
4. Tentar acessar outra rota → middleware bloqueia com 403 `MUST_CHANGE_PASSWORD`
5. Submeter nova senha
6. Backend grava `password_changed_at` + zera `must_change_password`
7. Frontend libera navegação

## 3. Email verification

**Pré-condição:** usuário com `email_verified_at IS NULL` e `email IS NOT NULL`

1. Backend envia link + OTP por email após registro
2. Web: clicar link → `/verify-email/:token` → marca verificado
3. Flutter: tela OTP → digitar código → marca verificado
4. Token inválido/expirado → erro claro
5. Reenvio de email → rate limit aplicado

## 4. 2FA TOTP

**Setup (opt-in):**
1. Acessar Perfil → "Configurar 2FA"
2. Backend gera secret, retorna QR code
3. Escanear no Google Authenticator
4. Digitar primeiro código → backend confirma + gera 8 backup codes
5. Codes exibidos UMA vez (não armazenados em texto plano)

**Login com 2FA:**
1. Login normal retorna `pre_auth_token` (TTL 5min) com flag `totp_required`
2. Tela TOTP → digitar código de 6 dígitos
3. Backend valida com `pre_auth_token` → emite token completo
4. Pre_auth_token expirado → forçar relogin

**Backup codes:**
1. Login → escolher "Usar código de backup" → digitar 1 dos 8 codes
2. Backend marca code usado (single-use)
3. Quando restam ≤3 codes → avisar usuário

**Disable 2FA:**
1. Acessar Perfil → "Desativar 2FA"
2. Pedir senha atual + código TOTP
3. Backend zera `totp_enabled`, `totp_secret`, `totp_confirmed_at` e remove backup codes

## 5. Master role + admin console

**Pré-condição:** usuário com `nivel_acesso='master'`

1. Login → menu mostra entrada "Admin"
2. Acessar dashboard admin → métricas globais carregam
3. Listar profissionais → filtro por nível + ativo/inativo
4. Feature flags → criar/editar/togglar
5. Gerenciar usuários → criar/editar/desativar
6. Auditoria → filtros por tabela/ação/data/matrícula

**Gates de segurança:**
- Login como `gerente` → menu Admin NÃO aparece
- `gerente` tentando acessar `/admin/*` no Angular → AdminGuard redireciona
- `gerente` chamando `/api/v2/admin/*` direto → backend retorna 401

## 6. Push notifications

**Web:**
1. Login → menu mostra sino de notificações
2. Clicar sino → painel abre com lista vazia inicial
3. Clicar "Ativar notificações" → browser solicita permissão
4. Aceitar → OneSignal SDK gera playerId → POST `/v2/notifications/token`
5. Backend insere em `push_tokens` (matricula + player_id + plataforma='web')
6. Receber notificação via OneSignal dashboard de teste
7. Logout → DELETE `/v2/notifications/token` remove playerId

**Flutter:**
1. Login → push service `init()` (sem popup)
2. Perfil → botão "Ativar notificações"
3. Tap → OneSignal solicita permissão nativa
4. Aceitar → POST `/v2/notifications/token` (plataforma='android' ou 'ios')
5. Receber push de teste
6. Logout → DELETE remove playerId + OneSignal logout

**Backend jobs:**
1. Verificar `saveAndNotify` em jobs cria registro em `notifications` ANTES do envio
2. Verificar push chega ao dispositivo

## 7. Fluxos CRUD principais

**Estabelecimentos / Licenças / Termos / Denúncias / Atividades / Protocolos / Embasamentos / Documentos:**

Por feature:
1. Listar — paginação OK, busca OK
2. Cadastrar — validação client + server, redirect após save
3. Editar — pré-preencher form, save
4. Anexos (quando aplicável) — upload imagem, listar, deletar
5. PDF (quando aplicável) — download, abrir
6. Email (quando aplicável) — enviar PDF por email

**Domínio crítico — Termos:**
- Workflow de status (aberto → andamento → fechado)
- Assinatura digital
- Cálculo de prazos retorno

## 8. Migrations pós-deploy

```bash
# Heroku release phase roda automaticamente, mas verificar:
heroku run -a ambiente-visa "npx sequelize-cli db:migrate:status"
```

Esperar todas migrations "up".

## 9. Health checks

- `GET /` → 200 com info de versão
- `GET /api/v2/dashboard` (auth) → métricas
- Logs Sentry → sem erros novos
- Heroku logs → sem erros 5xx repetidos
- OneSignal dashboard → app registrado + entrega OK

## Critérios de aceite

Smoke OK se:
- Todos os fluxos 1-7 passam sem erro
- Migrations todas aplicadas
- Logs Sentry/Heroku sem erros 5xx novos
- Push chega ao dispositivo em até 30s
- Admin console gates funcionam (master vs gerente)
