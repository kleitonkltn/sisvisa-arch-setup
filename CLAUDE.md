# Sisvisa Project Overview

**Purpose:** This repository manages architecture setup and external documentation for the Sisvisa project.

# Sisvisa workspace guidance

- Treat `sisvisa` as a trusted read-heavy workspace for repo exploration.
- Never read `.env`, `.env.*`, private keys, or credential files.
- Prefer direct read-only inspection flows with `git status`, `git log`, `git diff`, `git show`, `rg`, `ls`, `find`, and `cat`.
- Avoid compound commands like `cd ... && git ...`; prefer operating from the current workspace root or using `git -C <repo>` for read-only inspection.
- Ask before destructive or external side-effect actions such as `git push`, `git commit`, deletion, deploys, or production mutations.

## Claude Code Skills Base

- Use `.claude/skills/sisvisa-product-quality.md` for UI/UX/product/operational flows in SisVisa.
- Use `.claude/skills/humanized-communication.md` when converting technical output into a clear report for Kleiton, public managers or stakeholders.
- Prefer Flutter for new mobile work; Ionic is legacy and should be used only for critical maintenance.
- For SisVisa outputs, include technical summary, operational impact and risks/QA.

## Project Components

### sisvisa_web (Angular Web Application)
- **Purpose**: Angular 9 web application for SisVisa, a municipal visa/inspection management system for Brazilian municipal health surveillance. Manages establishments, licenses, protocols, complaints, terms, reports, activities, and supporting documents for regulatory inspectors.
- **Technologies**: Angular 9.1, PrimeNG 9, Angular Material 9, ng2-charts, Firebase, JWT authentication. Uses TSLint.
- **Build/Run**: `npm run build`, `npm start` (development), `npm test` (unit tests), `npm run lint`, `npm run deploy`. Requires `NODE_OPTIONS=--openssl-legacy-provider`.
- **Testing**: Unit tests with Jasmine + Karma (`npm test`), E2E with Protractor (`npm run e2e`).
- **Structure**: Feature components in `src/app/presenter/features/<domain>/`, shared components in `src/app/components/`, HTTP services in `src/app/services/`, data contracts in `src/models/`. All routes in `src/app/app.module.ts`.

### sisvisa-api (Node.js/Express REST API)
- **Purpose**: REST API for SisVisa. Serves municipal health inspectors with license management, inspection scheduling, and document generation. Exposes v1 and v2 API surfaces from a single Node.js/Express process.
- **Technologies**: Node.js/Express (v4.21.2), PostgreSQL (via Sequelize v6.37.8), AWS S3, OneSignal (push notifications), SMTP (email), Sentry (error tracking). Uses Babel for transpilation, ESLint 9, and Conventional Commits.
- **Build/Run**: `npm run build` after changes. Production runs from `dist/`. Requires Node.js >=22.0.0.
- **Testing**: `npm run build` (transpile check), `npm run audit:test` (system integration audit).
- **Structure**: `src/app.js` (Express app factory), `src/bin/www.js` (HTTP server entry point). Two API versions: `src/routes/` (v1) and `src/v2/` (v2).
- **Deployment**: Heroku app `ambiente-visa`.

### sisvisa_flutter_app (Flutter Mobile/Desktop/Web Application)
- **Purpose**: Flutter application for SisVisa, a government licensing and inspection management system. It's a migration project from an Ionic/Angular app, still receiving parity adjustments. Supports multiple platforms (Android, iOS, macOS, Linux, Windows, Web) and multiple branding flavors.
- **Technologies**: Flutter, Dart, `flutter_bloc` (Cubit for state management), `go_router` (navigation), `dio` (HTTP client), `local_auth` (biometrics), `shared_preferences`/`flutter_secure_storage` (local persistence).
- **Build/Run**: `flutter pub get` (after `pubspec.yaml` changes), `dart run flavorizr` (after `flavorizr.yaml` changes), `slidy` CLI (for new features).
- **Testing**: `flutter test` from root. Test files mirror `lib/` structure. Cubit tests use `bloc_test`.
- **Structure**: Clean Architecture (data -> domain -> presentation layers per feature). Multi-branding support.
- **Status**: Migration project; several features are placeholders (e.g., documentos, embasamentos, atividades). Backlog for migration status in `docs/knowledge/backlog-migracao.md`.
