import { useState, useEffect } from 'react'

const STATUS_COLORS = {
  Submitted: '#6366f1',
  'Under Review': '#f59e0b',
  Approved: '#10b981',
  'In Progress': '#3b82f6',
  Done: '#22c55e',
  Declined: '#ef4444',
}

function IdeaCard({ idea }) {
  return (
    <div style={{
      border: '1px solid #e5e7eb',
      borderRadius: 8,
      padding: '1rem',
      marginBottom: '1rem',
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <h3 style={{ margin: 0 }}>{idea.title}</h3>
        <span style={{
          background: STATUS_COLORS[idea.status] ?? '#6b7280',
          color: '#fff',
          padding: '2px 10px',
          borderRadius: 12,
          fontSize: 12,
          whiteSpace: 'nowrap',
        }}>
          {idea.status}
        </span>
      </div>
      {idea.description && (
        <p style={{ color: '#6b7280', marginTop: 8, marginBottom: 8 }}>{idea.description}</p>
      )}
      <div style={{ display: 'flex', gap: 8, fontSize: 12, color: '#9ca3af' }}>
        {idea.category && <span>#{idea.category}</span>}
        <span>{new Date(idea.submittedAt).toLocaleDateString()}</span>
      </div>
    </div>
  )
}

function SubmitForm({ onSubmitted }) {
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [category, setCategory] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [message, setMessage] = useState(null)

  async function handleSubmit(e) {
    e.preventDefault()
    if (!title.trim()) return
    setSubmitting(true)
    setMessage(null)
    try {
      const res = await fetch('/api/ideas', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title, description, category }),
      })
      if (res.ok) {
        setMessage({ ok: true, text: 'Idea submitted — thanks!' })
        setTitle('')
        setDescription('')
        setCategory('')
        onSubmitted()
      } else {
        setMessage({ ok: false, text: `Error ${res.status} — please try again.` })
      }
    } catch {
      setMessage({ ok: false, text: 'Network error — please try again.' })
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} style={{ marginBottom: '2rem' }}>
      <h2>Submit an Idea</h2>
      {message && (
        <p style={{ color: message.ok ? '#10b981' : '#ef4444', margin: '0 0 8px' }}>
          {message.text}
        </p>
      )}
      <div style={{ marginBottom: 8 }}>
        <input
          type="text"
          placeholder="Title *"
          value={title}
          onChange={e => setTitle(e.target.value)}
          required
          style={{ width: '100%', padding: 8, boxSizing: 'border-box', fontSize: 14 }}
        />
      </div>
      <div style={{ marginBottom: 8 }}>
        <textarea
          placeholder="Description (optional)"
          value={description}
          onChange={e => setDescription(e.target.value)}
          rows={3}
          style={{ width: '100%', padding: 8, boxSizing: 'border-box', fontSize: 14 }}
        />
      </div>
      <div style={{ marginBottom: 8 }}>
        <input
          type="text"
          placeholder="Category (optional)"
          value={category}
          onChange={e => setCategory(e.target.value)}
          style={{ width: '100%', padding: 8, boxSizing: 'border-box', fontSize: 14 }}
        />
      </div>
      <button
        type="submit"
        disabled={submitting}
        style={{ padding: '8px 18px', cursor: submitting ? 'not-allowed' : 'pointer', fontSize: 14 }}
      >
        {submitting ? 'Submitting…' : 'Submit Idea'}
      </button>
    </form>
  )
}

export default function IdeasPage() {
  const [ideas, setIdeas] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  async function loadIdeas() {
    try {
      const res = await fetch('/api/ideas')
      if (res.status === 501) {
        // Stub not yet implemented — show empty state
        setIdeas([])
        return
      }
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      setIdeas(await res.json())
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { loadIdeas() }, [])

  return (
    <main style={{ fontFamily: 'sans-serif', maxWidth: 640, margin: '2rem auto', padding: '0 1rem' }}>
      <h1>Ideas Board</h1>
      <SubmitForm onSubmitted={loadIdeas} />
      <h2>All Ideas</h2>
      {loading && <p>Loading…</p>}
      {error && <p style={{ color: '#ef4444' }}>Error: {error}</p>}
      {!loading && !error && ideas.length === 0 && (
        <p style={{ color: '#9ca3af' }}>No ideas yet — be the first to submit one!</p>
      )}
      {ideas.map(idea => <IdeaCard key={idea.id} idea={idea} />)}
    </main>
  )
}
