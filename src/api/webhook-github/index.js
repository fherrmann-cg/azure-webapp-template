'use strict'

/**
 * POST /api/webhook/github
 * Receives GitHub webhook events (Issues, Label).
 *
 * STUB: returns 501 Not Implemented.
 * Replace this function body in derived projects.
 *
 * Implementation checklist:
 *   1. Validate x-hub-signature-256 header against github-webhook-secret from Key Vault
 *   2. Parse event type from x-github-event header
 *   3. On 'issues' event + action 'labeled' + label.name === 'approved':
 *        a. Update idea status in Table Storage to 'Approved'
 *        b. Dispatch a workflow_dispatch event to trigger Copilot Workspace draft PR
 *   4. Return 200 OK for all recognised events, 400 for invalid signature
 *
 * Auth: retrieve webhook secret via DefaultAzureCredential + @azure/keyvault-secrets
 *   const { DefaultAzureCredential } = require('@azure/identity')
 *   const { SecretClient } = require('@azure/keyvault-secrets')
 */
module.exports = async function webhookGitHub(context, _req) {
  context.res = {
    status: 501,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      error: 'Not Implemented',
      message: 'Replace this stub with your implementation. See comments in src/api/webhook-github/index.js.',
    }),
  }
}
