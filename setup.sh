#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# azure-webapp-template — one-command project bootstrap
#
# Usage:
#   ./setup.sh APP_NAME=my-app GITHUB_ORG=fherrmann-cg [AZURE_REGION=switzerlandnorth]
#
# What this does:
#   1. Substitutes {{APP_NAME}}, {{AZURE_REGION}}, {{GITHUB_ORG}} placeholders
#   2. Creates the Azure resource group
#   3. Creates an Entra ID app registration with OIDC federated credentials
#      (no long-lived secrets — GitHub Actions uses OIDC)
#   4. Assigns Contributor role on the resource group to the app
#   5. Deploys the Bicep base stack (computeType=swa by default)
#   6. Creates GitHub issue labels
#   7. Prints the 'gh variable set' commands to wire up CI/CD
# ──────────────────────────────────────────────────────────────────────────────

# ── Parse named arguments ─────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    APP_NAME=*)     APP_NAME="${arg#*=}" ;;
    GITHUB_ORG=*)   GITHUB_ORG="${arg#*=}" ;;
    AZURE_REGION=*) AZURE_REGION="${arg#*=}" ;;
  esac
done

APP_NAME="${APP_NAME:-}"
GITHUB_ORG="${GITHUB_ORG:-fherrmann-cg}"
AZURE_REGION="${AZURE_REGION:-switzerlandnorth}"

if [[ -z "$APP_NAME" ]]; then
  echo "ERROR: APP_NAME is required."
  echo "Usage: ./setup.sh APP_NAME=my-app GITHUB_ORG=fherrmann-cg"
  exit 1
fi

RESOURCE_GROUP="rg-fh-${APP_NAME}"
GH_REPO="${GITHUB_ORG}/${APP_NAME}"
APP_DISPLAY_NAME="${APP_NAME}-gh-actions"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  azure-webapp-template bootstrap"
echo "  APP_NAME       : ${APP_NAME}"
echo "  GITHUB_ORG     : ${GITHUB_ORG}"
echo "  AZURE_REGION   : ${AZURE_REGION}"
echo "  RESOURCE_GROUP : ${RESOURCE_GROUP}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Step 1: Substitute placeholders ──────────────────────────────────────────
echo "→ [1/6] Substituting placeholders..."

FILES_TO_UPDATE=$(grep -rl \
  --include="*.json" --include="*.yml" --include="*.yaml" \
  --include="*.md"   --include="*.bicep" --include="*.jsx" \
  --include="*.js"   --include="*.sh"    --include="*.html" \
  --include="*.ts"   --include="*.tsx" \
  --exclude-dir=node_modules --exclude-dir=.git \
  -e "{{APP_NAME}}" -e "{{AZURE_REGION}}" -e "{{GITHUB_ORG}}" \
  . 2>/dev/null || true)

for f in $FILES_TO_UPDATE; do
  sed -i.bak \
    -e "s|{{APP_NAME}}|${APP_NAME}|g" \
    -e "s|{{AZURE_REGION}}|${AZURE_REGION}|g" \
    -e "s|{{GITHUB_ORG}}|${GITHUB_ORG}|g" \
    "$f"
  rm -f "${f}.bak"
  echo "   patched: $f"
done

# ── Step 2: Create Azure resource group ──────────────────────────────────────
echo ""
echo "→ [2/6] Creating resource group '${RESOURCE_GROUP}' in '${AZURE_REGION}'..."
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${AZURE_REGION}" \
  --output table

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# ── Step 3: OIDC federated credential setup ───────────────────────────────────
echo ""
echo "→ [3/6] Setting up OIDC federated credentials for GitHub Actions..."

# Create or reuse the Entra ID app registration
EXISTING_APP_ID=$(az ad app list \
  --display-name "${APP_DISPLAY_NAME}" \
  --query "[0].appId" -o tsv 2>/dev/null || echo "")

if [[ -n "$EXISTING_APP_ID" && "$EXISTING_APP_ID" != "None" ]]; then
  APP_ID="$EXISTING_APP_ID"
  echo "   Using existing app registration: ${APP_ID}"
else
  APP_ID=$(az ad app create \
    --display-name "${APP_DISPLAY_NAME}" \
    --query appId -o tsv)
  echo "   Created app registration: ${APP_ID}"
fi

# Create service principal if not already present
SP_EXISTS=$(az ad sp show --id "${APP_ID}" --query appId -o tsv 2>/dev/null || echo "")
if [[ -z "$SP_EXISTS" || "$SP_EXISTS" == "None" ]]; then
  az ad sp create --id "${APP_ID}" --output none
  echo "   Service principal created"
else
  echo "   Service principal already exists"
fi

# Add federated credential for main branch (idempotent via name)
add_federated_credential() {
  local CRED_NAME="$1"
  local SUBJECT="$2"
  local DESCRIPTION="$3"

  EXISTING=$(az ad app federated-credential list \
    --id "${APP_ID}" \
    --query "[?name=='${CRED_NAME}'].name" -o tsv 2>/dev/null || echo "")

  if [[ -n "$EXISTING" ]]; then
    echo "   Federated credential '${CRED_NAME}' already exists — skipping"
    return
  fi

  az ad app federated-credential create \
    --id "${APP_ID}" \
    --parameters "{
      \"name\": \"${CRED_NAME}\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"${SUBJECT}\",
      \"description\": \"${DESCRIPTION}\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" \
    --output none
  echo "   Federated credential '${CRED_NAME}' added"
}

add_federated_credential \
  "${APP_NAME}-main" \
  "repo:${GH_REPO}:ref:refs/heads/main" \
  "GitHub Actions — main branch deploy"

add_federated_credential \
  "${APP_NAME}-prs" \
  "repo:${GH_REPO}:pull_request" \
  "GitHub Actions — PR checks"

# Assign Contributor on the resource group (idempotent)
echo "   Assigning Contributor role on ${RESOURCE_GROUP}..."
az role assignment create \
  --role "Contributor" \
  --assignee "${APP_ID}" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}" \
  --output none 2>/dev/null || echo "   (Contributor role already assigned)"

# ── Step 4: Deploy Bicep base stack ──────────────────────────────────────────
echo ""
echo "→ [4/6] Deploying Bicep base stack (computeType=swa)..."
az deployment group create \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file infra/main.bicep \
  --parameters @infra/parameters.switzerland-north.json \
  --parameters appName="${APP_NAME}" \
  --output table

# ── Step 5: Create GitHub issue labels ───────────────────────────────────────
echo ""
echo "→ [5/6] Creating GitHub issue labels on ${GH_REPO}..."
create_label() {
  gh label create "$1" --color "$2" --description "$3" --repo "${GH_REPO}" 2>/dev/null \
    || gh label edit "$1" --color "$2" --description "$3" --repo "${GH_REPO}" 2>/dev/null \
    || echo "   label '$1' already exists"
}
create_label "idea"        "6366f1" "New idea submitted via /ideas board"
create_label "approved"    "10b981" "Idea approved — Copilot Workspace will open a draft PR"
create_label "in-progress" "3b82f6" "Work in progress"
create_label "done"        "22c55e" "Completed"
create_label "declined"    "ef4444" "Idea declined"

# ── Step 6: Print GitHub Actions variable setup ───────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  [6/6] Set these GitHub Actions repository variables"
echo "  (run the commands below, or set them in GitHub UI)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  gh variable set AZURE_CLIENT_ID       --body '${APP_ID}'             --repo ${GH_REPO}"
echo "  gh variable set AZURE_TENANT_ID       --body '${TENANT_ID}'          --repo ${GH_REPO}"
echo "  gh variable set AZURE_SUBSCRIPTION_ID --body '${SUBSCRIPTION_ID}'   --repo ${GH_REPO}"
echo "  gh variable set AZURE_RESOURCE_GROUP  --body '${RESOURCE_GROUP}'    --repo ${GH_REPO}"
echo "  gh variable set AZURE_APP_NAME        --body '${APP_NAME}'           --repo ${GH_REPO}"
echo ""
echo "  Next steps:"
echo "  1. Run the 'gh variable set' commands above"
echo "  2. Store Key Vault secrets:"
echo "       az keyvault secret set --vault-name kv-fh-${APP_NAME} --name github-pat --value '<your-pat>'"
echo "       az keyvault secret set --vault-name kv-fh-${APP_NAME} --name github-webhook-secret --value '$(openssl rand -hex 32)'"
echo "  3. Register a GitHub webhook:"
echo "       URL: https://swa-fh-${APP_NAME}.azurestaticapps.net/api/webhook/github"
echo "       Events: Issues, Label"
echo "  4. Enable 'Template repository' in GitHub repo Settings > General"
echo ""
echo "  Bootstrap complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
