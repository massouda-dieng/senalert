import clsx from 'clsx';
import {
  Activity, Bell, BookOpenCheck, Bot, Building2, ClipboardList, FileClock, FolderOpen, Gauge, Home, LogOut, Map,
  MapPinned, Megaphone, Menu, Moon, Presentation, Sun, PanelLeftClose, PanelLeftOpen, Search, Settings2, ShieldAlert, Siren, SlidersHorizontal,
  Smartphone, Tags, UserCircle2, Users, UsersRound, WifiOff, X,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { Link, NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useRessource } from '../api/hooks';
import { estSupervision, useAuth } from '../auth/AuthContext';
import { useConfig } from '../lib/config';
import { useInstallation } from '../lib/installation';
import { useLangue } from '../lib/langue';
import { appliquerTheme, choisirTheme, themeChoisi } from '../lib/theme';
import AlertesTempsReel from './AlertesTempsReel';
import { Logo } from './Logo';

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
  ],
  // Superviseur d'une structure : uniquement les dossiers et les agents de sa structure.
  superviseur: [
    { a: '/supervision', libelle: 'Ma structure', icone: Gauge, fin: true },
    { a: '/supervision/incidents', libelle: 'Incidents', icone: ClipboardList },
    { a: '/supervision/sos', libelle: 'Alertes SOS', icone: Siren },
    { a: '/supervision/carte', libelle: 'Carte interactive', icone: Map },
    { groupe: 'Équipe' },
    { a: '/supervision/utilisateurs', libelle: 'Mes agents', icone: Users },
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
    { a: '/supervision/structures', libelle: 'Structures', icone: Building2 },
    { a: '/supervision/referentiels', libelle: 'Services & catégories', icone: Tags },
    { a: '/supervision/parametres', libelle: 'Paramètres', icone: SlidersHorizontal },
    { a: '/supervision/audit', libelle: "Journal d'audit", icone: FileClock },
    { a: '/supervision/demo', libelle: 'Démonstration', icone: Presentation },
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
  danger: 'bg-sos-clair text-sos-fonce border-l-4 border-sos',
  vigilance: 'bg-or-clair text-texte border-l-4 border-or-vif',
  info: 'bg-marque-50 text-marque-800 border-l-4 border-marque-600',
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
  const [sombre, setSombre] = useState(() => appliquerTheme(themeChoisi()));
  const { donnees: compteur } = useRessource('/notifications/compteur/', null, { intervalle: 30000 });
  const { langue, setLangue, t } = useLangue();
  const traduit = utilisateur.role === 'citoyen'; // seul l'espace citoyen est traduit en wolof
  const compteurs = {};
  const liens = NAVIGATION[utilisateur.role] || [];
  const nonLues = compteur?.non_lues || 0;
  // Les listes ont leur propre recherche : une seule barre à l'écran.
  const rechercheGlobale = utilisateur.role !== 'citoyen' && !/\/(interventions|incidents|sos)$/.test(lieu.pathname);
  const regionAlertes = utilisateur.role === 'agent' ? utilisateur.profil_agent?.zones?.[0] : utilisateur.region;

  useEffect(() => setMobileOuvert(false), [lieu.pathname]);
  useEffect(() => { try { localStorage.setItem('senalert.menu', replie ? 'replie' : 'ouvert'); } catch { /* rien */ } }, [replie]);

  const rechercher = (e) => {
    e.preventDefault();
    const q = recherche.trim();
    if (!q) return;
    const cible = utilisateur.role === 'agent' ? '/agent/interventions' : q.toUpperCase().startsWith('SOS') ? '/supervision/sos' : '/supervision/incidents';
    navigate(`${cible}?q=${encodeURIComponent(q)}`);
  };

  return (
    <div className="flex min-h-screen">
      <a href="#contenu" className="sr-only focus:not-sr-only focus:fixed focus:left-3 focus:top-3 focus:z-[2000] focus:rounded-lg focus:bg-surface focus:px-3 focus:py-2">Aller au contenu</a>

      <aside className={clsx('fixed inset-y-0 left-0 z-[900] flex flex-col overflow-hidden bg-marque-800 text-white transition-all duration-200 lg:sticky lg:top-0 lg:h-screen lg:translate-x-0',
        replie ? 'lg:w-[78px]' : 'lg:w-64', mobileOuvert ? 'w-72 translate-x-0' : 'w-72 -translate-x-full')}>
        <Link to="/" className={clsx('flex h-16 items-center gap-2.5 px-5', replie && 'lg:justify-center lg:px-0')}>
          <Logo className="h-9 w-9 shrink-0" clair />
          <div className={clsx(replie && 'lg:hidden')}>
            <p className="font-titre text-lg font-extrabold leading-none">SenAlert</p>
            <p className="text-[11px] text-white/65">{utilisateur.role_libelle}</p>
            {utilisateur.structure_nom && <p className="max-w-[11rem] truncate text-[11px] text-white/65" title={utilisateur.structure_nom}>{utilisateur.structure_nom}</p>}
          </div>
        </Link>
        <nav className="relative flex flex-1 flex-col gap-0.5 overflow-y-auto px-3 py-2" aria-label="Navigation principale">
          {liens.map((l, i) => (l.groupe ? (
            <p key={i} className={clsx('px-3 pb-1 pt-5 text-[11px] font-bold uppercase tracking-wider text-white/45', replie && 'lg:hidden')}>{l.groupe}</p>
          ) : (
            <NavLink key={l.a} to={l.a} end={l.fin} title={replie ? l.libelle : undefined}
              className={({ isActive }) => clsx('group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition',
                isActive ? 'bg-white text-marque-800 shadow-sm' : 'text-white/75 hover:bg-white/10 hover:text-white')}>
              <l.icone className="h-[18px] w-[18px] shrink-0" aria-hidden />
              <span className={clsx('truncate', replie && 'lg:sr-only')}>{traduit ? t(l.libelle) : l.libelle}</span>
              {compteurs[l.compteur] > 0 && <span className={clsx('ml-auto rounded-full bg-or px-2 py-0.5 text-[11px] font-bold text-black', replie && 'lg:hidden')} aria-label={`${compteurs[l.compteur]} en attente`}>{compteurs[l.compteur]}</span>}
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
        <header className="sticky top-0 z-[700] border-b border-surface-bord bg-surface/90 backdrop-blur">
          <div className="flex h-16 items-center gap-3 px-4 sm:px-6">
            <button type="button" className="rounded-lg p-2 hover:bg-surface-douce lg:hidden" onClick={() => setMobileOuvert(true)} aria-label="Ouvrir le menu"><Menu className="h-5 w-5" /></button>
            {rechercheGlobale && (
              <form onSubmit={rechercher} className="relative hidden max-w-md flex-1 sm:block" role="search">
                <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-texte-pale" aria-hidden />
                <input value={recherche} onChange={(e) => setRecherche(e.target.value)} className="champ rounded-full bg-surface-douce py-2 pl-9"
                  placeholder="Rechercher une référence, une adresse…" aria-label="Recherche" />
              </form>
            )}
            <div className="ml-auto flex items-center gap-1.5">
              {!enLigne && <span className="mr-2 inline-flex items-center gap-1.5 rounded-full bg-alerte-clair px-3 py-1 text-xs font-semibold text-alerte"><WifiOff className="h-3.5 w-3.5" /> Hors connexion</span>}
              {utilisateur.role === 'citoyen' && lieu.pathname !== '/citoyen' && (
                <NavLink to="/citoyen" className="mr-1 inline-flex items-center gap-1.5 rounded-full bg-sos-fonce px-3.5 py-1.5 text-xs font-bold text-white shadow-sm hover:bg-sos-sombre">
                  <Siren className="h-4 w-4" /> SOS
                </NavLink>
              )}
              {utilisateur.role !== 'citoyen' && <AlertesTempsReel role={utilisateur.role} />}
              {traduit && (
                <div className="mr-1 inline-flex rounded-full bg-surface-douce p-0.5 text-xs font-bold ring-1 ring-surface-bord" role="group" aria-label="Langue / Làkk">
                  {[['fr', 'FR', 'Français'], ['wo', 'WO', 'Wolof']].map(([code, court, long]) => (
                    <button key={code} type="button" onClick={() => setLangue(code)} aria-pressed={langue === code} title={long}
                      className={clsx('rounded-full px-2.5 py-1 transition', langue === code ? 'bg-marque-800 text-white' : 'text-texte-doux hover:text-texte')}>{court}</button>
                  ))}
                </div>
              )}
              <button type="button" onClick={() => setSombre(choisirTheme(sombre ? 'clair' : 'sombre'))} className="rounded-xl p-2.5 text-texte-doux hover:bg-surface-douce"
                aria-label={sombre ? 'Passer en mode clair' : 'Passer en mode sombre'} title={sombre ? 'Mode clair' : 'Mode sombre'}>
                {sombre ? <Sun className="h-5 w-5" /> : <Moon className="h-5 w-5" />}
              </button>
              <NavLink to="/notifications" className="relative rounded-xl p-2.5 text-texte-doux hover:bg-surface-douce" aria-label={`Notifications${nonLues ? ` (${nonLues} non lues)` : ''}`}>
                <Bell className="h-5 w-5" />
                {nonLues > 0 && <span className="absolute right-1 top-1 min-w-[18px] rounded-full bg-sos-fonce px-1 text-center text-[10px] font-bold leading-[18px] text-white">{nonLues > 99 ? '99+' : nonLues}</span>}
              </NavLink>
              <MenuProfil utilisateur={utilisateur} onDeconnexion={async () => { const role = utilisateur.role; await deconnexion(); navigate(role === 'citoyen' ? '/connexion' : `/connexion?espace=${role}`); }} />
            </div>
          </div>
          {!estSupervision(utilisateur.role) && <BandeauAlertesZone region={regionAlertes} />}
        </header>

        {utilisateur.doit_changer_mot_de_passe && lieu.pathname !== '/profil' && (
          <div className="bg-or-clair px-6 py-2 text-sm text-or-fonce">
            Votre compte utilise un mot de passe initial. <NavLink className="lien" to="/profil">Choisissez un mot de passe personnel</NavLink>.
          </div>
        )}
        {config?.erreur && <div className="bg-sos-clair px-6 py-2 text-sm text-sos-fonce">Configuration indisponible : certaines listes peuvent être vides. {config.erreur.detail}</div>}

        <main id="contenu" className="mx-auto w-full max-w-[1400px] flex-1 px-4 py-6 sm:px-6 lg:px-8" tabIndex={-1}>
          <Outlet />
        </main>
        <footer className="px-6 pb-24 text-center text-xs text-texte-pale lg:pb-6">
          SenAlert ne remplace pas les services officiels de secours. En cas de danger immédiat, appelez directement {config?.numeros_urgence?.map((n) => `${n.service} ${n.numero}`).join(' · ') || 'les secours'}.
          {' '}<Link to="/credits" className="underline">Crédits photos</Link>
        </footer>
        <BarreMobile role={utilisateur.role} traduire={traduit ? t : (x) => x} onMenu={() => setMobileOuvert(true)} />
      </div>
    </div>
  );
}

const BARRE_MOBILE = {
  citoyen: [['/citoyen', 'Accueil', Home, true], ['/citoyen/signaler', 'Signaler', ShieldAlert], ['/citoyen/dossiers', 'Dossiers', FolderOpen], ['/citoyen/carte', 'Carte', Map]],
  agent: [['/agent', 'Tableau', Gauge, true], ['/agent/interventions', 'Missions', ClipboardList], ['/agent/carte', 'Carte', Map], ['/notifications', 'Alertes', Bell]],
  superadmin: [['/supervision', 'Vue d’ensemble', Gauge, true], ['/supervision/incidents', 'Incidents', ClipboardList], ['/supervision/sos', 'SOS', Siren], ['/supervision/carte', 'Carte', Map]],
  superviseur: [['/supervision', 'Ma structure', Gauge, true], ['/supervision/incidents', 'Incidents', ClipboardList], ['/supervision/sos', 'SOS', Siren], ['/supervision/utilisateurs', 'Agents', Users]],
};

/** Barre d'onglets du téléphone : les écrans clés restent à portée de pouce, le reste est dans « Menu ». */
function BarreMobile({ role, traduire, onMenu }) {
  return (
    <nav className="fixed inset-x-0 bottom-0 z-[700] grid grid-cols-5 border-t border-surface-bord bg-surface/95 pb-[env(safe-area-inset-bottom)] backdrop-blur lg:hidden" aria-label="Navigation rapide">
      {(BARRE_MOBILE[role] || []).map(([a, libelle, Icone, fin]) => (
        <NavLink key={a} to={a} end={fin} className={({ isActive }) => clsx('flex flex-col items-center gap-0.5 py-2 text-[11px] font-semibold', isActive ? 'text-marque-800' : 'text-texte-doux')}>
          <Icone className="h-5 w-5" aria-hidden /><span className="max-w-full truncate px-1">{traduire(libelle)}</span>
        </NavLink>
      ))}
      <button type="button" onClick={onMenu} className="flex flex-col items-center gap-0.5 py-2 text-[11px] font-semibold text-texte-doux">
        <Menu className="h-5 w-5" aria-hidden />Menu
      </button>
    </nav>
  );
}

function MenuProfil({ utilisateur, onDeconnexion }) {
  const [ouvert, setOuvert] = useState(false);
  const installation = useInstallation();
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
        <span className="grid h-8 w-8 place-items-center rounded-full bg-marque-600 text-sm font-bold text-white ">{initiale}</span>
        <span className="hidden max-w-[140px] truncate text-sm font-semibold md:block">{utilisateur.first_name || utilisateur.username}</span>
      </button>
      {ouvert && (
        <>
          <div className="fixed inset-0 z-10" onClick={() => setOuvert(false)} aria-hidden />
          <div role="menu" className="absolute right-0 z-20 mt-2 w-60 animate-apparition rounded-2xl border border-surface-bord bg-surface p-1.5 shadow-flottant">
            <div className="px-3 py-2">
              <p className="truncate text-sm font-semibold">{utilisateur.email || utilisateur.username}</p>
              <p className="text-xs text-texte-doux">{utilisateur.role_libelle}{utilisateur.structure_nom ? ` · ${utilisateur.structure_nom}` : ''}</p>
            </div>
            <NavLink role="menuitem" to="/profil" onClick={() => setOuvert(false)} className="flex items-center gap-2.5 rounded-xl px-3 py-2 text-sm hover:bg-surface-douce"><UserCircle2 className="h-4 w-4" /> Profil et sécurité</NavLink>
            {installation.possible && !installation.ios && <button role="menuitem" type="button" onClick={() => { setOuvert(false); installation.installer(); }} className="flex w-full items-center gap-2.5 rounded-xl px-3 py-2 text-sm hover:bg-surface-douce"><Smartphone className="h-4 w-4" /> Installer l’application</button>}
            <NavLink role="menuitem" to="/simulateur" onClick={() => setOuvert(false)} className="flex items-center gap-2.5 rounded-xl px-3 py-2 text-sm hover:bg-surface-douce"><Smartphone className="h-4 w-4" /> Simulateur mobile</NavLink>
            {utilisateur.role === 'superadmin' && <a role="menuitem" href="/admin/" className="flex items-center gap-2.5 rounded-xl px-3 py-2 text-sm hover:bg-surface-douce"><Settings2 className="h-4 w-4" /> Administration technique</a>}
            {utilisateur.role === 'superadmin' && <a role="menuitem" href="/api/docs/" target="_blank" rel="noreferrer" className="flex items-center gap-2.5 rounded-xl px-3 py-2 text-sm hover:bg-surface-douce"><Building2 className="h-4 w-4" /> Documentation API</a>}
            <button role="menuitem" type="button" onClick={onDeconnexion} className="flex w-full items-center gap-2.5 rounded-xl px-3 py-2 text-sm text-sos-fonce hover:bg-sos-clair"><LogOut className="h-4 w-4" /> Se déconnecter</button>
          </div>
        </>
      )}
    </div>
  );
}
