// /ideas/admin — protected by Entra ID via staticwebapp.config.json
// Unauthenticated requests are redirected to /.auth/login/aad by SWA.
import { useState, useEffect } from 'react'

const STATUSES = ['Submitted', 'Under Review', 'Approved', 'In Progress', 'Done', 'Declined']

export default function IdeasAdmin() {
  const [ideas, setIdeas] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    fetch('/api/ideas')
      .then(r => {
        if (r.status === 501) return []
        if (!r.ok) throw new Error(`HTTP ${r.status}`)
        return r.json()
      })
      .then(data => { setIdeas(data); setLoading(false) })
      .catch(err => { setError(err.message); setLoading(false) })
  }, [])

  if (loading) return <p style={{ fontFamily: 'sans-serif', margin: '2rem' }}>Loading…</p>
  if (error) return <p style={{ fontFamily: 'sans-serif', margin: '2rem', color: '#ef4444' }}>Error: {error}</p>

  return (
    <main style={{ fontFamily: 'sans-serif', maxWidth: 900, margin: '2rem auto', padding: '0 1rem' }}>
      <h1>Ideas Admin</h1>
      <p style={{ color: '#6b7280' }}>
        Update idea status here, or change GitHub Issue labels —
        the webhook at <code>/api/webhook/github</code> syncs label changes automatically.
      </p>
      {ideas.length === 0 ? (
        <p style={{ color: '#9ca3af' }}>No ideas submitted yet.</p>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 14 }}>
          <thead>
            <tr style={{ borderBottom: '2px solid #e5e7eb', textAlign: 'left' }}>
              <th style={{ padding: '8px 12px' }}>Title</th>
              <th style={{ padding: '8px 12px' }}>Category</th>
              <th style={{ padding: '8px 12px' }}>Status</th>
              <th style={{ padding: '8px 12px' }}>Submitted</th>
            </tr>
          </thead>
          <tbody>
            {ideas.map(idea => (
              <tr key={idea.id} style={{ borderBottom: '1px solid #f3f4f6' }}>
                <td style={{ padding: '8px 12px' }}>{idea.title}</td>
                <td style={{ padding: '8px 12px', color: '#6b7280' }}>
                  {idea.category || '—'}
                </td>
                <td style={{ padding: '8px 12px' }}>
                  <select defaultValue={idea.status} style={{ fontSize: 13 }}>
                    {STATUSES.map(s => <option key={s}>{s}</option>)}
                  </select>
                </td>
                <td style={{ padding: '8px 12px', color: '#9ca3af', whiteSpace: 'nowrap' }}>
                  {new Date(idea.submittedAt).toLocaleDateString()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </main>
  )
}
