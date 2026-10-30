import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import { FournisseurAuth } from './auth/AuthContext';
import { FournisseurToasts } from './components/ui';
import { FournisseurConfig } from './lib/config';
import './index.css';
import { appliquerTheme, suivreSysteme } from './lib/theme';

appliquerTheme();
suivreSysteme();

// Application installable et disponible hors connexion (version compilée uniquement, jamais dans un cadre).
if (import.meta.env.PROD && 'serviceWorker' in navigator && window.top === window.self) {
  window.addEventListener('load', () => navigator.serviceWorker.register('/app/sw.js', { scope: '/app/' }).catch(() => {}));
}

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <BrowserRouter basename="/app" future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
      <FournisseurToasts>
        <FournisseurConfig>
          <FournisseurAuth>
            <App />
          </FournisseurAuth>
        </FournisseurConfig>
      </FournisseurToasts>
    </BrowserRouter>
  </StrictMode>,
);
