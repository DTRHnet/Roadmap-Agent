import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Proxy target: match FastAPI (RMA_WEB_PORT / RMA_WEB_HOST). Hub sets RMA_WEB_VITE_PROXY_TARGET when starting Vite.
const apiProxy =
  process.env.RMA_WEB_VITE_PROXY_TARGET?.trim() || 'http://127.0.0.1:8765'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': {
        target: apiProxy,
        changeOrigin: true,
      },
    },
  },
})
