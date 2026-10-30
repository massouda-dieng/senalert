import clsx from 'clsx';
import {
  Activity, Bell, BookOpenCheck, Bot, Building2, ClipboardList, FileClock, FolderOpen, Gauge, Home, LogOut, Map,
  MapPinned, Menu, PanelLeftClose, PanelLeftOpen, Search, Settings2, ShieldAlert, Siren, SlidersHorizontal, Tags,
  UserCircle2, Users, WifiOff,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useRessource } from '../api/hooks';
import { useAuth } from '../auth/AuthContext';
import { useConfig } from '../lib/config';
import { Logo } from './Logo';

export const NAVIGATION = {
  citoyen: [
    { a: '/citoyen', libelle: 'Accueil', icone: Home, fin: true },
    { a: '/citoyen/signaler', libelle: 'Signaler un incident', icone: ShieldAlert },
    { a: '/citoyen/dossiers', libelle: 'Mes dossiers', icone: FolderOpen },
    { a: '/citoyen/carte', libelle: 'Carte des incidents', icone: Map },
    { a: '/citoyen/services', libelle: 'Services proches', icone: MapPinned },
    { a: '/citoyen/secours', libelle: 'Premiers secours', icone: BookOpenCheck },
    { a: '/citoyen/assistant', libelle: 'Assistant', icone: Bot },
  ],
  agent: [
    { a: '/agent', libelle: 'Tableau de bord', icone: Gauge, fin: true },
    { a: '/agent/interventions', libelle: 'Interventions', icone: ClipboardList },
    { a: '/agent/carte', libelle: 'Carte opérationnelle', icone: Map },
    { a: '/agent/secours', libelle: 'Premiers secours', icone: BookOpenCheck },
  ],
  superadmin: [
    { a: '/supervision', libelle: 'Supervision', icone: Gauge, fin: true },
    { a: '/supervision/incidents', libelle: 'Incidents', icone: ClipboardList },
    { a: '/supervision/sos', libelle: 'Alertes SOS', icone: Siren },
    { a: '/supervision/risques', libelle: 'Carte & risques', icone: Activity },
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

  const menu = (
    <nav className="flex flex-1 flex-col gap-0.5 overflow-y-auto px-3 py-2" aria-label="Navigation principale">
      {liens.map((l, i) => (l.groupe ? (
        <p key={i} className={clsx('px-3 pb-1 pt-5 text-[11px] font-bold uppercase tracking-wider text-white/40', replie && 'lg:hidden')}>{l.groupe}</p>
      ) : (
        <NavLink key={l.a} to={l.a} end={l.fin} title={replie ? l.libelle : undefined}
          className={({ isActive }) => clsx('group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition',
            isActive ? 'bg-white/10 text-white shadow-[inset_3px_0_0_#F97316]' : 'text-white/70 hover:bg-white/5 hover:text-white')}>
          <l.icone className="h-[18px] w-[18px] shrink-0" aria-hidden />
          <span className={clsx('truncate', replie && 'lg:sr-only')}>{l.libelle}</span>
        </NavLink>
      )))}
    </nav>
  );

  return (
    <div className="flex min-h-screen">
      <a href="#contenu" className="sr-only focus:not-sr-only focus:fixed focus:left-3 focus:top-3 focus:z-[2000] focus:rounded-lg focus:bg-white focus:px-3 focus:py-2">Aller au contenu</a>

      {/* Barre latérale */}
      <aside className={clsx('fixed inset-y-0 left-0 z-[900] flex flex-col bg-gradient-to-b from-nuit-900 to-nuit-950 text-white transition-all duration-200 lg:sticky lg:top-0 lg:h-screen lg:translate-x-0',
        replie ? 'lg:w-[76px]' : 'lg:w-64', mobileOuvert ? 'w-72 translate-x-0' : 'w-72 -translate-x-full')}>
        <div className={clsx('flex h-16 items-center gap-2.5 px-5', replie && 'lg:justify-center lg:px-0')}>
          <Logo className="h-8 w-8 shrink-0" />
          <div className={clsx(replie && 'lg:hidden')}>
            <p className="font-titre text-lg font-extrabold leading-none">SenAlert</p>
            <p className="text-[11px] text-white/50">{utilisateur.role_libelle}</p>
          </div>
        </div>
        {menu}
        <div className="border-t border-white/10 p-3">
          <button type="button" onClick={() => setReplie((r) => !r)} className="hidden w-full items-center gap-3 rounded-xl px-3 py-2 text-sm text-white/60 hover:bg-white/5 hover:text-white lg:flex" aria-label={replie ? 'Déplier le menu' : 'Replier le menu'}>
            {replie ? <PanelLeftOpen className="h-[18px] w-[18px]" /> : <><PanelLeftClose className="h-[18px] w-[18px]" /> Replier</>}
          </button>
        </div>
      </aside>
      {mobileOuvert && <div className="fixed inset-0 z-[800] bg-nuit-950/50 lg:hidden" onClick={() => setMobileOuvert(false)} aria-hidden />}

      <div className="flex min-w-0 flex-1 flex-col">
        {/* Barre supérieure */}
        <header className="sticky top-0 z-[700] flex h-16 items-center gap-3 border-b border-surface-bord bg-white/55 px-4 backdrop-blur sm:px-6">
          <button type="button" className="rounded-lg p-2 hover:bg-surface-douce lg:hidden" onClick={() => setMobileOuvert(true)} aria-label="Ouvrir le menu"><Menu className="h-5 w-5" /></button>
          <form onSubmit={rechercher} className="relative hidden max-w-md flex-1 sm:block" role="search">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-texte-pale" aria-hidden />
            <input value={recherche} onChange={(e) => setRecherche(e.target.value)} className="champ rounded-full bg-surface-douce py-2 pl-9"
              placeholder={utilisateur.role === 'citoyen' ? 'Rechercher un de mes dossiers (référence)…' : 'Rechercher une référence, une adresse…'} aria-label="Recherche" />
          </form>
          <div className="ml-auto flex items-center gap-1.5">
            {!enLigne && <span className="mr-2 inline-flex items-center gap-1.5 rounded-full bg-alerte-clair px-3 py-1 text-xs font-semibold text-amber-800"><WifiOff className="h-3.5 w-3.5" /> Hors connexion</span>}
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
        </header>

        {utilisateur.doit_changer_mot_de_passe && lieu.pathname !== '/profil' && (
          <div className="bg-alerte-clair px-6 py-2 text-sm text-amber-900">
            Votre compte utilise un mot de passe initial. <NavLink className="lien" to="/profil">Choisissez un mot de passe personnel</NavLink>.
          </div>
        )}
        {config?.erreur && <div className="bg-red-50 px-6 py-2 text-sm text-red-800">Configuration indisponible : certaines listes peuvent être vides. {config.erreur.detail}</div>}

        <main id="contenu" className="mx-auto w-full max-w-[1400px] flex-1 px-4 py-6 sm:px-6 lg:px-8" tabIndex={-1}>
          <Outlet />
        </main>
        <footer className="px-6 pb-6 text-center text-xs text-texte-pale">
          SenAlert ne remplace pas les services officiels de secours. En cas de danger immédiat, appelez directement {config?.numeros_urgence?.map((n) => `${n.service} ${n.numero}`).join(' · ') || 'les secours'}.
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
        <span className="grid h-8 w-8 place-items-center rounded-full bg-nuit-800 text-sm font-bold text-white">{initiale}</span>
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
            {utilisateur.role === 'superadmin' && (
              <a role="menuitem" href="/admin/" className="flex items-center gap-2.5 rounded-xl px-3 py-2 text-sm hover:bg-surface-douce"><Settings2 className="h-4 w-4" /> Administration technique</a>
            )}
            {utilisateur.role === 'superadmin' && (
              <a role="menuitem" href="/api/docs/" target="_blank" rel="noreferrer" className="flex items-center gap-2.5 rounded-xl px-3 py-2 text-sm hover:bg-surface-douce"><Building2 className="h-4 w-4" /> Documentation API</a>
            )}
            <button role="menuitem" type="button" onClick={onDeconnexion} className="flex w-full items-center gap-2.5 rounded-xl px-3 py-2 text-sm text-red-700 hover:bg-red-50"><LogOut className="h-4 w-4" /> Se déconnecter</button>
          </div>
        </>
      )}
    </div>
  );
}
