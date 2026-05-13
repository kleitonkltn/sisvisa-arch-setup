# SisVisa Product Quality Pack

Use quando a tarefa tocar UI, UX, Flutter, Angular web, app legado Ionic, verificação pública, relatórios, fluxos de vigilância sanitária, licenças, estabelecimentos, termos, documentos ou jornadas de servidor/contribuinte.

## Objetivo
Garantir que mudanças no SisVisa sejam claras, seguras, auditáveis e fáceis de usar por equipes públicas, fiscais, gestores e cidadãos.

## Projetos SisVisa
- `sisvisa-api/`: Node 22 + Express 4 + Sequelize + PostgreSQL + JWT.
- `sisvisa_flutter_app/`: Flutter/Dart 3 + Cubit + GoRouter + Dio. Alvo da migração mobile.
- `sisvisa-app/`: Ionic 4 + Angular 8 legado. Manutenção mínima.
- `sisvisa_web/`: Angular 9 + Nx + Material. Admin web.
- `sisvisa-public/`: Firebase Functions/Hosting para verificação pública de PDFs via QR.

## Workflow obrigatório
1. Identifique usuário afetado: fiscal, gestor, estabelecimento, cidadão ou suporte.
2. Mapeie fluxo atual antes de alterar.
3. Prefira `/api/v2` para novas features na API.
4. Em mobile, priorize Flutter; Ionic só para bug crítico legado.
5. Defina estados: loading, vazio, erro, sem internet, sessão expirada, permissão negada.
6. Preserve auditabilidade: quem fez, quando, status, protocolo/documento, histórico.
7. Não alterar auth/JWT, secrets, produção ou deploy sem confirmação explícita.
8. Entregue resumo técnico e resumo executivo em linguagem pública/operacional.

## Regras de qualidade visual
- Interface precisa ser objetiva, legível e operacional.
- Não esconder informações críticas atrás de padrões bonitos mas pouco claros.
- Tabelas/listas devem priorizar busca, filtro, status, data e ação principal.
- Formulários devem ter validação clara e mensagens de erro humanas.
- PDF/QR/verificação pública deve transmitir confiança e autenticidade.

## Checklist de risco SisVisa
- Quebra compatibilidade com app legado?
- Mudança exige migration idempotente com `up` e `down`?
- Afeta permissões/perfis?
- Afeta geração/verificação de PDF?
- Afeta fluxo público ou dado sensível?
- Precisa atualizar docs de migração Ionic -> Flutter?

## Definition of done
- Projeto correto escolhido.
- Contrato API/documento validado.
- Estados de tela e erros tratados.
- Segurança e dados sensíveis preservados.
- Validação/build/teste executado ou justificativa clara.
- Saída inclui: resumo técnico, impacto operacional/comercial e riscos/QA.
