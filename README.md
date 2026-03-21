# azure-webapp-template

A production-ready GitHub template for Azure web applications.
Built for the `fherrmann-cg` project baseline — Static Web App + integrated Functions, Key Vault, Application Insights, OIDC CI/CD, and a `/ideas` board wired to GitHub Issues.

---

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) logged in with Contributor access
- [Node.js 20+](https://nodejs.org/)
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated
- [Azure Functions Core Tools v4](https://docs.microsoft.com/azure/azure-functions/functions-run-local)

---

## Quick Start

1. Click **"Use this template"** on GitHub to create a new repo.
2. Clone your new repo and `cd` into it.
3. Run the bootstrap script:

```bash
./setup.sh APP_NAME=my-app GITHUB_ORG=fherrmann-cg AZURE_REGION=switzerlandnorth
```

This script will:
- Substitute all `{{APP_NAME}}` / `{{AZURE_REGION}}` / `{{GITHUB_ORG}}` placeholders
- Create the Azure resource group
- Register an Entra ID app with OIDC federated credentials for GitHub Actions
- Deploy the full Bicep stack
- Print the `gh variable set` commands to configure your repo

4. Set the GitHub Actions repository variables printed by `setup.sh`.
5. Push to `main` — the pipeline deploys automatically.

---

## Architecture

**Default compute:** `swa` (Azure Static Web App + integrated Functions) — free tier, global CDN, zero server management.

**Primary region:** Switzerland North. **Fallback:** Sweden Central.

| Service | Purpose |
|---|---|
| Azure Static Web App | Frontend hosting + API runtime |
| Azure Key Vault | Secret storage (GitHub PAT, webhook secret) |
| Application Insights + Log Analytics | Observability |
| User-assigned Managed Identity | Passwordless Azure auth |
| Azure Table Storage | Ideas board persistence |

---

## Compute Types

| Value | Description |
|---|---|
| `swa` | Static Web App with integrated Functions (default) |
| `functionapp` | Standalone Consumption-plan Function App |

Pass `computeType=functionapp` to the Bicep deployment to switch.

---

## CI/CD

Two workflows:

| Workflow | Trigger | Steps |
|---|---|---|
| `deploy.yml` | Push to `main` | lint → build → OIDC login → deploy to SWA |
| `pr-checks.yml` | Pull request | lint → build → API unit tests |

**No long-lived secrets in GitHub.** OIDC federated credentials are configured by `setup.sh`.
The SWA deployment token is fetched dynamically at deploy time via `az staticwebapp secrets list`.

### Required repository variables

| Variable | Description |
|---|---|
| `AZURE_CLIENT_ID` | OIDC app registration client ID |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `AZURE_RESOURCE_GROUP` | Resource group (`rg-fh-{{APP_NAME}}`) |
| `AZURE_APP_NAME` | App name (used to resolve SWA resource name) |

---

## /ideas Board

Public idea submission form → GitHub Issue → label-driven status machine.

```
User submits idea  →  POST /api/ideas
                   →  Azure Function creates GitHub Issue (label: "idea")
                   →  Idea stored in Table Storage

GitHub label → "approved"
                   →  Webhook  →  POST /api/webhook/github
                   →  Function updates Table Storage status
                   →  Function dispatches GitHub Actions workflow_dispatch
                   →  Copilot Workspace opens draft PR
```

**Setup (once per derived project):**
1. Store GitHub PAT (`repo` scope) in Key Vault as `github-pat`
2. Store webhook secret in Key Vault as `github-webhook-secret`
3. Register a GitHub webhook → `https://[swa-url]/api/webhook/github` (events: Issues, Label)

**Admin route** (`/ideas/admin`) is protected by Entra ID — configure SWA auth in the Azure portal after deployment.

---

## Post-Bootstrap Steps

- **Custom domain + TLS:** Azure SWA portal → Custom domains
- **Database:** Add Cosmos DB / PostgreSQL Bicep modules yourself
- **Multi-region:** Out of scope for this template
- **Copilot Workspace:** See GitHub docs for `workflow_dispatch` trigger setup

---

## Placeholder Reference

| Placeholder | Example |
|---|---|
| `{{APP_NAME}}` | `my-app` |
| `{{AZURE_REGION}}` | `switzerlandnorth` |
| `{{GITHUB_ORG}}` | `fherrmann-cg` |

`setup.sh` replaces all placeholders on first run.
