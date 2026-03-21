# CLAUDE.md — azure-webapp-template

This file gives Claude Code the full context needed to navigate and work in this repo without additional briefing.

---

## Purpose

This is a **GitHub Template Repository** — not a deployed application. It is the scaffold every new `fherrmann-cg` web project derives from. When a user clicks "Use this template" on GitHub and then runs `setup.sh`, they get a fully wired Azure deployment in under 30 minutes.

---

## File Map

```
.github/workflows/deploy.yml       Push to main → OIDC login → build → deploy to SWA
.github/workflows/pr-checks.yml    PR → lint + build + API unit tests (blocks merge)
infra/main.bicep                   Parametrised Bicep: swa or functionapp compute mode
infra/parameters.switzerland-north.json   Switzerland North defaults
infra/parameters.sweden-central.json      Sweden Central fallback
src/app/                           React (Vite) frontend — entry: index.html / main.jsx
src/app/ideas/IdeasPage.jsx        /ideas public board
src/app/ideas/IdeasAdmin.jsx       /ideas/admin (Entra ID protected)
src/api/health/                    GET /api/health → 200 OK
src/api/ideas/                     GET + POST /api/ideas → 501 stub
src/api/webhook-github/            POST /api/webhook/github → 501 stub
staticwebapp.config.json           SWA routing + /ideas/admin auth guard
setup.sh                           One-command bootstrap (placeholders + Azure infra + OIDC)
```

---

## Placeholder Convention

All template placeholders: `{{UPPER_SNAKE_CASE}}`

| Placeholder | Purpose |
|---|---|
| `{{APP_NAME}}` | Project/resource name (e.g. `my-app`) |
| `{{AZURE_REGION}}` | Azure region slug (e.g. `switzerlandnorth`) |
| `{{GITHUB_ORG}}` | GitHub org/user (e.g. `fherrmann-cg`) |

`setup.sh` performs find-and-replace across all relevant files on first bootstrap.

---

## Key Commands

```bash
# Bootstrap a new project from this template
./setup.sh APP_NAME=my-app GITHUB_ORG=fherrmann-cg AZURE_REGION=switzerlandnorth

# Deploy infrastructure only
az deployment group create \
  --resource-group rg-fh-{{APP_NAME}} \
  --template-file infra/main.bicep \
  --parameters @infra/parameters.switzerland-north.json \
  --parameters appName={{APP_NAME}} computeType=swa

# Run frontend locally
cd src/app && npm install && npm run dev

# Run functions locally
cd src/api && npm install && func start

# Run lint
cd src/app && npm run lint

# Run API tests
cd src/api && npm test
```

---

## Architecture Decisions

- **No long-lived secrets in GitHub.** All secrets in Key Vault. GitHub Actions uses OIDC federated credentials.
- **SWA deployment token fetched dynamically** via `az staticwebapp secrets list` during deploy, not stored as a GitHub secret.
- **Managed Identity** for all Azure service-to-service calls (Key Vault, Table Storage).
- **Function stubs return 501.** Derived projects replace the body — never modify the stub pattern itself.
- **computeType=swa default.** Storage Account is provisioned when `computeType=functionapp` OR `includeIdeasBoard=true`.

---

## Conventions

- Resource naming prefix: `fh-{{APP_NAME}}` (e.g. `kv-fh-my-app`, `swa-fh-my-app`)
- Resource group: `rg-fh-{{APP_NAME}}`
- Bicep idempotent: running `az deployment group create` twice must not error
- All new API routes: add `src/api/<route>/index.js` + `function.json` following existing stubs
- All new frontend pages: add component + route entry in `App.jsx`

---

## Common Claude Code Tasks

- **Add API route:** Copy `src/api/health/` as template. Add `function.json` (methods, authLevel) + `index.js` stub.
- **Add frontend page:** Create component, add `<Route>` in `App.jsx`, add link in nav.
- **Modify infra:** Edit `infra/main.bicep`. Validate with `az bicep build --file infra/main.bicep` before deploying.
- **Implement ideas API:** Replace stub body in `src/api/ideas/index.js` using `@azure/data-tables` + `@azure/keyvault-secrets` + `@azure/identity`.
- **Implement webhook:** Replace stub body in `src/api/webhook-github/index.js`. Validate `x-hub-signature-256` header first.
