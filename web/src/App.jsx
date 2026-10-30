import { lazy, Suspense } from 'react';
import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { ESPACE_PAR_ROLE, useAuth } from './auth/AuthContext';
import Layout from './components/Layout';
import { Chargement } from './components/ui';
import { Interventions, TableauAgent } from './pages/agent/Agent';
import { Audit, Parametres, Referentiels } from './pages/admin/Configuration';
import { IncidentsAdmin, SOSAdmin } from './pages/admin/Dossiers';
import Risques from './pages/admin/Risques';
import Utilisateurs from './pages/admin/Utilisateurs';
import { Connexion, DemandeAgent, Inscription, MotDePasseOublie, Reinitialiser } from './pages/auth/Auth';
import Accueil from './pages/citoyen/Accueil';
import Assistant from './pages/citoyen/Assistant';
import Guide from './pages/citoyen/Guide';
import MesDossiers from './pages/citoyen/MesDossiers';
import Services from './pages/citoyen/Services';
import Signaler from './pages/citoyen/Signaler';
import AlertesZone from './pages/admin/AlertesZone';
import DemandesAgent from './pages/admin/DemandesAgent';
import Demonstration from './pages/admin/Demonstration';
import CartePage from './pages/commun/CartePage';
import Communaute from './pages/commun/Communaute';
import Credits from './pages/commun/Credits';
import Notifications from './pages/commun/Notifications';
import Simulateur from './pages/Simulateur';
import Vitrine from './pages/Vitrine';
import Profil from './pages/commun/Profil';

// Chargé à la demande : les graphiques ne pèsent pas sur les espaces citoyen et agent.
const Supervision = lazy(() => import('./pages/admin/Supervision'));

/** Garde de route : la vraie protection est côté serveur ; ceci évite d'afficher un espace inaccessible. */
function Espace({ roles, children }) {
  const { utilisateur, initialise } = useAuth();
  const lieu = useLocation();
  if (!initialise) return <Chargement texte="Ouverture de la session…" className="min-h-screen" />;
  if (!utilisateur) return <Navigate to="/connexion" replace state={{ depuis: lieu.pathname + lieu.search }} />;
  if (roles && !roles.includes(utilisateur.role)) return <Navigate to={ESPACE_PAR_ROLE[utilisateur.role]} replace />;
  return children;
}

function Public({ children }) {
  const { utilisateur, initialise } = useAuth();
  if (!initialise) return <Chargement className="min-h-screen" />;
  return utilisateur ? <Navigate to={ESPACE_PAR_ROLE[utilisateur.role]} replace /> : children;
}

export default function App() {
  return (
    <Routes>
      <Route path="/connexion" element={<Public><Connexion /></Public>} />
      <Route path="/inscription" element={<Public><Inscription /></Public>} />
      <Route path="/demande-agent" element={<Public><DemandeAgent /></Public>} />
      <Route path="/mot-de-passe-oublie" element={<Public><MotDePasseOublie /></Public>} />
      <Route path="/reinitialiser" element={<Reinitialiser />} />
      <Route path="/" element={<Vitrine />} />
      <Route path="/credits" element={<Credits />} />
      <Route path="/simulateur" element={<Simulateur />} />

      <Route element={<Espace><Layout /></Espace>}>
        <Route path="/citoyen" element={<Espace roles={['citoyen']}><Accueil /></Espace>} />
        <Route path="/citoyen/signaler" element={<Espace roles={['citoyen']}><Signaler /></Espace>} />
        <Route path="/citoyen/dossiers" element={<Espace roles={['citoyen']}><MesDossiers /></Espace>} />
        <Route path="/citoyen/carte" element={<Espace roles={['citoyen']}><CartePage /></Espace>} />
        <Route path="/citoyen/communaute" element={<Espace roles={['citoyen']}><Communaute /></Espace>} />
        <Route path="/citoyen/services" element={<Espace roles={['citoyen']}><Services /></Espace>} />
        <Route path="/citoyen/secours" element={<Espace roles={['citoyen']}><Guide /></Espace>} />
        <Route path="/citoyen/assistant" element={<Espace roles={['citoyen']}><Assistant /></Espace>} />

        <Route path="/agent" element={<Espace roles={['agent']}><TableauAgent /></Espace>} />
        <Route path="/agent/interventions" element={<Espace roles={['agent']}><Interventions /></Espace>} />
        <Route path="/agent/carte" element={<Espace roles={['agent']}><CartePage /></Espace>} />
        <Route path="/agent/secours" element={<Espace roles={['agent']}><Guide /></Espace>} />

        <Route path="/supervision" element={<Espace roles={['superadmin']}><Suspense fallback={<Chargement />}><Supervision /></Suspense></Espace>} />
        <Route path="/supervision/incidents" element={<Espace roles={['superadmin']}><IncidentsAdmin /></Espace>} />
        <Route path="/supervision/sos" element={<Espace roles={['superadmin']}><SOSAdmin /></Espace>} />
        <Route path="/supervision/carte" element={<Espace roles={['superadmin']}><CartePage /></Espace>} />
        <Route path="/supervision/demo" element={<Espace roles={['superadmin']}><Demonstration /></Espace>} />
        <Route path="/supervision/alertes-zone" element={<Espace roles={['superadmin']}><AlertesZone /></Espace>} />
        <Route path="/supervision/communaute" element={<Espace roles={['superadmin']}><Communaute /></Espace>} />
        <Route path="/supervision/risques" element={<Espace roles={['superadmin']}><Risques /></Espace>} />
        <Route path="/supervision/demandes-agent" element={<Espace roles={['superadmin']}><DemandesAgent /></Espace>} />
        <Route path="/supervision/utilisateurs" element={<Espace roles={['superadmin']}><Utilisateurs /></Espace>} />
        <Route path="/supervision/referentiels" element={<Espace roles={['superadmin']}><Referentiels /></Espace>} />
        <Route path="/supervision/parametres" element={<Espace roles={['superadmin']}><Parametres /></Espace>} />
        <Route path="/supervision/audit" element={<Espace roles={['superadmin']}><Audit /></Espace>} />

        <Route path="/notifications" element={<Notifications />} />
        <Route path="/profil" element={<Profil />} />
      </Route>
      <Route path="*" element={<Espace><RedirectionRole /></Espace>} />
    </Routes>
  );
}

function RedirectionRole() {
  const { utilisateur } = useAuth();
  return <Navigate to={ESPACE_PAR_ROLE[utilisateur.role] || '/connexion'} replace />;
}
