import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import { FournisseurAuth } from './auth/AuthContext';
import { FournisseurToasts } from './components/ui';
import { FournisseurConfig } from './lib/config';
import './index.css';

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
