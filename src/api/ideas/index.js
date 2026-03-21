'use strict'

/**
 * GET  /api/ideas  — list ideas from Table Storage
 * POST /api/ideas  — submit idea, create GitHub Issue, store in Table Storage
 *
 * STUB: returns 501 Not Implemented.
 * Replace this function body in derived projects using:
 *   - @azure/data-tables  (TableClient)  for persistence
 *   - @azure/keyvault-secrets + @azure/identity  for GitHub PAT retrieval
 *   - GitHub REST API (POST /repos/:owner/:repo/issues) to create the Issue
 *
 * Expected POST body: { title: string, description?: string, category?: string }
 * Expected GET response: Array<{ id, title, description, category, status, submittedAt }>
 */
module.exports = async function ideas(context, _req) {
  context.res = {
    status: 501,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      error: 'Not Implemented',
      message: 'Replace this stub with your implementation. See comments in src/api/ideas/index.js.',
    }),
  }
}
