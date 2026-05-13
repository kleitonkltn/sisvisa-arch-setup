# Smoke Test — SisVisa Admin Console

Execute após Tracks A+B concluídos.

## Pré-requisitos
- PostgreSQL local com `DATABASE_URL2` apontando
- Node 22+ em ambos projetos
- Usuário `nivel_acesso = gerente` existente na tabela `usuarios`

## Backend

```bash
cd /Users/kleitonrocha/Development/sisvisa/sisvisa-api

# Migrations
npx sequelize-cli db:migrate                # aplica feature_flags + last_login_at
npx sequelize-cli db:migrate:status         # confirmar UP

# Build + start
npm run build
npm run server                              # porta 3000

# Login (token JWT)
TOKEN=$(curl -s -X POST http://localhost:3000/api/v2/users/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"matricula":<MATRICULA_GERENTE>,"password":"<SENHA>"}' \
  | jq -r '.data.token')

# Smoke endpoints
curl -s http://localhost:3000/api/v2/admin/dashboard      -H "Authorization: Bearer $TOKEN" | jq
curl -s http://localhost:3000/api/v2/admin/professionals  -H "Authorization: Bearer $TOKEN" | jq
curl -s http://localhost:3000/api/v2/admin/audit?limit=5  -H "Authorization: Bearer $TOKEN" | jq
curl -s http://localhost:3000/api/v2/admin/feature-flags  -H "Authorization: Bearer $TOKEN" | jq

# Criar flag
curl -s -X POST http://localhost:3000/api/v2/admin/feature-flags \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"key":"new_dashboard","description":"Novo dashboard","enabled":true,"rollout_percentage":50}' | jq

# Toggle
curl -s -X PATCH http://localhost:3000/api/v2/admin/feature-flags/new_dashboard/toggle \
  -H "Authorization: Bearer $TOKEN" | jq

# Reset senha (não retorna senha — só status)
curl -s -X POST http://localhost:3000/api/v2/admin/users/<MATRICULA>/reset-password \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"send_email":false}' | jq

# Verificar 403 com fiscal (não-gerente)
TOKEN_FISCAL=...
curl -s http://localhost:3000/api/v2/admin/dashboard -H "Authorization: Bearer $TOKEN_FISCAL"
# esperado: {"success":false,"error":"...","statusCode":403}
```

## Frontend

```bash
cd /Users/kleitonrocha/Development/sisvisa/sisvisa_web

npm run start
# abre em http://localhost:4200
```

Login com gerente. Verificar:
1. Menu mostra grupo "Admin" com 5 sub-itens
2. `/admin/dashboard` carrega 4 cards + tabela by_fiscal
3. `/admin/profissionais` lista fiscais com contadores; clicar em fiscal abre `/admin/profissionais/:matricula` (timeline)
4. `/admin/feature-flags` mostra tabela; toggle inline funciona; "Nova flag" abre form; criar/editar/excluir funcionam
5. `/admin/usuarios` mostra CRUD; reset-senha mostra confirmação; criar novo retorna senha temp
6. `/admin/audit` permite filtros e paginação; clicar em entry abre dialog com old_values/new_values

Login com fiscal (não-gerente):
- Menu NÃO deve mostrar grupo Admin
- Acesso direto a `/admin/dashboard` redireciona para `/home`

## Build prod (sanity)

```bash
cd /Users/kleitonrocha/Development/sisvisa/sisvisa-api && npm run build
cd /Users/kleitonrocha/Development/sisvisa/sisvisa_web && npm run build
```

Ambos devem completar sem erro.
