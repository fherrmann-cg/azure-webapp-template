import { BrowserRouter, Routes, Route, Link } from 'react-router-dom'
import IdeasPage from './ideas/IdeasPage.jsx'
import IdeasAdmin from './ideas/IdeasAdmin.jsx'

function Home() {
  return (
    <main style={{ fontFamily: 'sans-serif', maxWidth: 640, margin: '2rem auto', padding: '0 1rem' }}>
      <h1>{{APP_NAME}}</h1>
      <p>Replace this placeholder with your application content.</p>
      <nav>
        <Link to="/ideas">Ideas Board &rarr;</Link>
      </nav>
    </main>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/ideas" element={<IdeasPage />} />
        <Route path="/ideas/admin" element={<IdeasAdmin />} />
      </Routes>
    </BrowserRouter>
  )
}
