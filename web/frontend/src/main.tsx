import { StrictMode, useEffect, useState } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { EnvStudioPage } from './EnvStudioPage.tsx'

function Root() {
  const [route, setRoute] = useState(() => window.location.hash.replace(/^#/, '') || '/')

  useEffect(() => {
    const onHash = () => setRoute(window.location.hash.replace(/^#/, '') || '/')
    window.addEventListener('hashchange', onHash)
    return () => window.removeEventListener('hashchange', onHash)
  }, [])

  if (route === '/env-studio' || route.startsWith('/env-studio')) {
    return <EnvStudioPage />
  }
  return <App />
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Root />
  </StrictMode>,
)
