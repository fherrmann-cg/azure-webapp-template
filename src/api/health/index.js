'use strict'

/**
 * GET /api/health
 * Returns 200 OK with a JSON status payload.
 * Used by load balancers and uptime monitors.
 */
module.exports = async function health(context, _req) {
  context.res = {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      status: 'ok',
      version: process.env.BUILD_ID ?? 'local',
      timestamp: new Date().toISOString(),
    }),
  }
}
