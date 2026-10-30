import clsx from 'clsx';
import {
  Activity, Bell, BookOpenCheck, Bot, Building2, ClipboardList, FileClock, FolderOpen, Gauge, Home, LogOut, Map,
  MapPinned, Megaphone, Menu, PanelLeftClose, PanelLeftOpen, Search, Settings2, ShieldAlert, Siren, SlidersHorizontal,
  Tags, UserCircle2, Users, UsersRound, WifiOff, X,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { Link, NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useRessource } from '../api/hooks';
import { useAuth } from '../auth/AuthContext';
import { useConfig } from '../lib/config';
import { BandeDrapeau, Logo } from './Logo';

export const NAVIGATION = {
  citoyen: [
    { a: '/citoyen', libelle: 'Accueil', icone: Home, fin: true },
    { a: '/citoyen/signaler', libelle: 'Signaler un incident', icone: ShieldAlert },
    { a: '/citoyen/dossiers', libelle: 'Mes dossiers', icone: FolderOpen },
    { a: '/citoyen/communaute', libelle: 'Autour de moi', icone: UsersRound },
    { a: '/citoyen/carte', libelle: 'Carte interactive', icone: Map },
    { a: '/citoyen/services', libelle: 'Services proches', icone: MapPinned },
    { a: '/citoyen/secours', libelle: 'Premiers secours', icone: BookOpenCheck },
    { a: '/citoyen/assistant', libelle: 'Assistant', icone: Bot },
  ],
  agent: [
    { a: '/agent', libelle: 'Tableau de bord', icone: Gauge, fin: true },
    { a: '/agent/interventions', libelle: 'Interventions', icone: ClipboardList },
    { a: '/agent/carte', libelle: 'Carte opérationnelle', icone: Map },
    { a: '/agent/communaute', libelle: 'Signalements citoyens', icone: UsersRound },
    { a: '/agent/secours', libelle: 'Premiers secours', icone: BookOpenCheck },
  ],
  superadmin: [
    { a: '/supervision', libelle: 'Supervision', icone: Gauge, fin: true },
    { a: '/supervision/incidents', libelle: 'Incidents', icone: ClipboardList },
    { a: '/supervision/sos', libelle: 'Alertes SOS', icone: Siren },
    { a: '/supervision/carte', libelle: 'Carte interactive', icone: Map },
    { a: '/supervision/risques', libelle: 'Zones de risque', icone: Activity },
    { a: '/supervision/alertes-zone', libelle: 'Alertes de zone', icone: Megaphone },
    { a: '/supervision/communaute', libelle: 'Communauté', icone: UsersRound },
    { groupe: 'Administration' },
    { a: '/supervision/utilisateurs', libelle: 'Utilisateurs', icone: Users },
    { a: '/supervision/referentiels', libelle: 'Services & catégories', icone: Tags },
    { a: '/supervision/parametres', libelle: 'Paramètres', icone: SlidersHorizontal },
    { a: '/supervision/audit', libelle: "Journal d'audit", icone: FileClock },
  ],
};

function useEnLigne() {
  const [enLigne, setEnLigne] = useState(navigator.onLine);
  useEffect(() => {
    const on = () => setEnLigne(true);
    const off = () => setEnLigne(false);
    window.addEventListener('online', on);
    window.addEventListener('offline', off);
    return () => { window.removeEventListener('online', on); window.removeEventListener('offline', off); };
  }, []);
  return enLigne;
}

const STYLE_NIVEAU = {
  danger: 'bg-sos text-white',
  vigilance: 'bg-or text-texte',
  info: 'bg-marque-700 text-white',
};

/** Bandeau des alertes de zone en cours pour la région de l'utilisateur. */
export function BandeauAlertesZone({ region }) {
  const { donnees } = useRessource('/alertes/zones/', { region: region || undefined, en_cours: 1 }, { intervalle: 120000 });
  const [masquees, setMasquees] = useState(() => { try { return JSON.parse(sessionStorage.getItem('senalert.alertes-masquees') || '[]'); } catch { return []; } });
  const alertes = (donnees?.results || []).filter((a) => !masquees.includes(a.id));
  if (!alertes.length) return null;
  const masquer = (id) => {
    const m = [...masquees, id];
    setMasquees(m);
    try { sessionStorage.setItem('senalert.alertes-masquees', JSON.stringify(m)); } catch { /* rien */ }
  };
  return (
    <div className="space-y-px" role="region" aria-label="Alertes de zone en cours">
      {alertes.slice(0, 3).map((a) => (
        <div key={a.id} className={clsx('flex items-start gap-3 px-4 py-2.5 text-sm sm:px-6', STYLE_NIVEAU[a.niveau])}>
          <Megaphone className="mt-0.5 h-4 w-4 shrink-0" aria-hidden />
          <p className="flex-1"><b>{a.titre}</b> — {a.message} <span className="opacity-75">({a.regions_libelles.join(', ')})</span></p>
          <button type="button" onClick={() => masquer(a.id)} className="rounded p-0.5 opacity-80 hover:opacity-100" aria-label="Masquer l'alerte"><X className="h-4 w-4" /></button>
        </div>
      ))}
    </div>
  );
}

export default function Layout() {
  const { utilisateur, deconnexion } = useAuth();
  const config = useConfig();
  const navigate = useNavigate();
  const lieu = useLocation();
  const enLigne = useEnLigne();
  const [replie, setReplie] = useState(() => { try { return localStorage.getItem('senalert.menu') === 'replie'; } catch { return false; } });
  const [mobileOuvert, setMobileOuvert] = useState(false);
  const [recherche, setRecherche] = useState('');
  const { donnees: compteur } = useRessource('/notifications/compteur/', null, { intervalle: 30000 });
  const liens = NAVIGATION[utilisateur.role] || [];
  const nonLues = compteur?.non_lues || 0;
  const regionAlertes = utilisateur.role === 'agent' ? utilisateur.profil_agent?.zones?.[0] : utilisateur.region;

  useEffect(() => setMobileOuvert(false), [lieu.pathname]);
  useEffect(() => { try { localStorage.setItem('senalert.menu', replie ? 'replie' : 'ouvert'); } catch { /* rien */ } }, [replie]);

  const rechercher = (e) => {
    e.preventDefault();
    const q = recherche.trim();
    if (!q) return;
    const cible = utilisateur.role === 'superadmin' ? (q.toUpperCase().startsWith('SOS') ? '/supervision/sos' : '/supervision/incidents')
      : utilisateur.role === 'agent' ? '/agent/interventions' : '/citoyen/dossiers';
    navigate(`${cible}?q=${encodeURIComponent(q)}`);
  };

  return (
    <div className="flex min-h-screen">
      <a href="#contenu" className="sr-only focus:not-sr-only focus:fixed focus:left-3 focus:top-3 focus:z-[2000] focus:rounded-lg focus:bg-white focus:px-3 focus:py-2">Aller au contenu</a>

      <aside className={clsx('fixed inset-y-0 left-0 z-[900] flex flex-col overflow-hidden bg-gradient-to-b from-marque-800 via-marque-900 to-marque-950 text-white transition-all duration-200 lg:sticky lg:top-0 lg:h-screen lg:translate-x-0',
        replie ? 'lg:w-[78px]' : 'lg:w-64', mobileOuvert ? 'w-72 translate-x-0' : 'w-72 -translate-x-full')}>
        {/* Étoile du drapeau en filigrane */}
        <svg viewBox="0 0 100 100" className="pointer-events-none absolute -bottom-10 -right-14 h-64 w-64 text-or opacity-[.07]" aria-hidden>
          <path fill="currentColor" d="m50 5 11 34h36L68 60l11 35-29-21-29 21 11-35L3 39h36z" />
        </svg>
        <BandeDrapeau className="h-1 shrink-0" />
        <Link to="/" className={clsx('flex h-16 items-center gap-2.5 px-5', replie && 'lg:justify-center lg:px-0')}>
          <Logo className="h-9 w-9 shrink-0" clair />
          <div className={clsx(replie && 'lg:hidden')}>
            <p className="font-titre text-lg font-extrabold leading-none">SenAlert</p>
            <p className="text-[11px] text-or/80">{utilisateur.role_libelle}</p>
          </div>
        </Link>
        <nav className="relative flex flex-1 flex-col gap-0.5 overflow-y-auto px-3 py-2" aria-label="Navigation principale">
          {liens.map((l, i) => (l.groupe ? (
            <p key={i} className={clsx('px-3 pb-1 pt-5 text-[11px] font-bold uppercase tracking-wider text-white/45', replie && 'lg:hidden')}>{l.groupe}</p>
          ) : (
            <NavLink key={l.a} to={l.a} end={l.fin} title={replie ? l.libelle : undefined}
              className={({ isActive }) => clsx('group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition',
                isActive ? 'bg-white text-marque-800 shadow-sm' : 'text-white/80 hover:bg-white/10 hover:text-white')}>
              <l.icone className="h-[18px] w-[18px] shrink-0" aria-hidden />
              <span className={clsx('truncate', replie && 'lg:sr-only')}>{l.libelle}</span>
            </NavLink>
          )))}
        </nav>
        <div className="relative border-t border-white/10 p-3">
          <button type="button" onClick={() => setReplie((r) => !r)} className="hidden w-full items-center gap-3 rounded-xl px-3 py-2 text-sm text-white/70 hover:bg-white/10 hover:text-white lg:flex" aria-label={replie ? 'Déplier le menu' : 'Replier le menu'}>
            {replie ? <PanelLeftOpen className="h-[18px] w-[18px]" /> : <><PanelLeftClose className="h-[18px] w-[18px]" /> Replier</>}
          </button>
        </div>
      </aside>
      {mobileOuvert && <div className="fixed inset-0 z-[800] bg-marque-950/50 lg:hidden" onClick={() => setMobileOuvert(false)} aria-hidden />}

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-[700] border-b border-surface-bord bg-white/90 backdrop-blur">
          <div className="flex h-16 items-center gap-3 px-4 sm:px-6">
            <button type="button" className="rounded-lg p-2 hover:bg-surface-douce lg:hidden" onClick={() => setMobileOuvert(true)} aria-label="Ouvrir le menu"><Menu className="h-5 w-5" /></button>
            <form onSubmit={rechercher} className="relative hidden max-w-md flex-1 sm:block" role="search">
              <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-texte-pale" aria-hidden />
              <input value={recherche} onChange={(e) => setRecherche(e.target.value)} className="champ rounded-full bg-surface-douce py-2 pl-9"
                placeholder={utilisateur.role === 'citoyen' ? 'Rechercher un de mes dossiers (référence)…' : 'Rechercher une référence, une adresse…'} aria-label="Recherche" />
            </form>
            <div className="ml-auto flex items-center gap-1.5">
              {!enLigne && <span className="mr-2 inline-flex items-center gap-1.5 rounded-full bg-alerte-clair px-3 py-1 text-xs font-semibold text-alerte"><WifiOff className="h-3.5 w-3.5" /> Hors connexion</span>}
              {utilisateur.role === 'citoyen' && (
                <NavLink to="/citoyen" className="mr-1 hidden items-center gap-1.5 rounded-full bg-sos px-3.5 py-1.5 text-xs font-bold text-white shadow-sm hover:bg-sos-fonce sm:inline-flex">
                  <Siren className="h-4 w-4" /> SOS
                </NavLink>
              )}
              <NavLink to="/notifications" className="relative rounded-xl p-2.5 text-texte-doux hover:bg-surface-douce" aria-label={`Notifications${nonLues ? ` (${nonLues} non lues)` : ''}`}>
                <Bell className="h-5 w-5" />
                {nonLues > 0 && <span className="absolute right-1 top-1 min-w-[18px] rounded-full bg-sos px-1 text-center text-[10px] font-bold leading-[18px] text-white">{nonLues > 99 ? '99+' : nonLues}</span>}
              </NavLink>
              <MenuProfil utilisateur={utilisateur} onDeconnexion={async () => { await deconnexion(); navigate('/connexion'); }} />
            </div>
          </div>
          {utilisateur.role !== 'superadmin' && <BandeauAlertesZone region={regionAlertes} />}
        </header>

        {utilisateur.doit_changer_mot_de_passe && lieu.pathname !== '/profil' && (
          <div className="bg-or-clair px-6 py-2 text-sm text-or-fonce">
            Votre compte utilise un mot de passe initial. <NavLink className="lien" to="/profil">Choisissez un mot de passe personnel</NavLink>.
          </div>
        )}
        {config?.erreur && <div className="bg-red-50 px-6 py-2 text-sm text-red-800">Configuration indisponible : certaines listes peuvent être vides. {config.erreur.detail}</div>}

        <main id="contenu" className="mx-auto w-full max-w-[1400px] flex-1 px-4 py-6 sm:px-6 lg:px-8" tabIndex={-1}>
          <Outlet />
        </main>
        <footer className="px-6 pb-6 text-center text-xs text-texte-pale">
          SenAlert ne remplace pas les services officiels de secours. En cas de danger immédiat, appelez directement {config?.numeros_urgence?.map((n) => `${n.service} ${n.numero}`).join(' · ') || 'les secours'}.
          {' '}<Link to="/credits" className="underline">Crédits photos</Link>
        </footer>
      </div>
    </div>
  );
}

function MenuProfil({ utilisateur, onDeconnexion }) {
  const [ouvert, setOuvert] = useState(false);
  const initiale = (utilisateur.first_name || utilisateur.username || '?')[0].toUpperCase();
  useEffect(() => {
    if (!ouvert) return undefined;
    const fermer = (e) => { if (e.key === 'Escape') setOuvert(false); };
    document.addEventListener('keydown', fermer);
    return () => document.removeEventListener('keydown', fermer);
  }, [ouvert]);
  return (
    <div className="relative">
      <button type="button" onClick={() => setOuvert((o) => !o)} aria-expanded={ouvert} aria-haspopup="menu"
        className="flex items-center gap-2 rounded-full py-1 pl-1 pr-2.5 hover:bg-surface-douce">
        <span className="grid h-8 w-8 place-items-center rounded-full bg-marque-600 text-sm font-bold text-white ring-2 ring-or">{initiale}</span>
        <span className="hidden max-w-[140px] truncate text-sm font-semibold md:block">{utilisateur.first_name || utilisateur.username}</span>
      </button>
      {ouvert && (
        <>
          <div className="fixed inset-0 z-10" onClick={() => setOuvert(false)} aria-hidden />
          <div role="menu" className="absolute right-0 z-20 mt-2 w-60 animate-apparition rounded-2xl border border-surface-bord bg-white p-1.5 shadow-flottant">
            <div className="px-3 py-2">
              <p className="truncate text-sm font-semibold">{utilisateur.email || utilisateur.username}</p>
              <p className="text-xs text-texte-doux">{utilisateur.role_libelle}{utilisateur.profil_agent?.service_nom ? ` · ${utilisateur.profil_agent.service_nom}` : ''}</p>
            </div>
            <NavLink role="menuitem" to="/profil" onClick={() => setOuvert(false)} className="flex items-center gap-2.5 rounded-xl px-3 py-2 text-sm hover:bg-surface-douce"><UserCircle2 className="h-4 w-4" /> Profil et sécurité</NavLink>
            {utilisateur.role === 'superadmin' && <a role="menuitem" href="/admin/" className="flex items-center gap-2.5 rounded-xl px-3 py-2 text-sm hover:bg-surface-douce"><Settings2 className="h-4 w-4" /> Administration technique</a>}
            {utilisateur.role === 'superadmin' && <a role="menuitem" href="/api/docs/" target="_blank" rel="noreferrer" className="flex items-center gap-2.5 rounded-xl px-3 py-2 text-sm hover:bg-surface-douce"><Building2 className="h-4 w-4" /> Documentation API</a>}
            <button role="menuitem" type="button" onClick={onDeconnexion} className="flex w-full items-center gap-2.5 rounded-xl px-3 py-2 text-sm text-red-700 hover:bg-red-50"><LogOut className="h-4 w-4" /> Se déconnecter</button>
          </div>
        </>
      )}
    </div>
  );
}
