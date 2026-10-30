import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// En développement, Vite relaie /api vers Django : même origine, aucun CORS à ouvrir.
// En production, `npm run build` produit web/dist servi par Django sous /app/.
export default defineConfig(({ command }) => ({
  // Dev : servi par Vite sous /app/. Build : fichiers servis par Django sous /static/.
  base: command === 'build' ? '/static/' : '/app/',
  plugins: [react()],
  server: {
    port: 5173,
    proxy: { '/api': 'http://127.0.0.1:8000' },
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
    rollupOptions: {
      output: {
        manualChunks: {
          react: ['react', 'react-dom', 'react-router-dom'],
          carte: ['leaflet', 'react-leaflet', 'leaflet.markercluster'],
        },
      },
    },
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.js'],
    css: false,
  },
}));
