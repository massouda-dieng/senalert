import clsx from 'clsx';
import {
  ArrowRight, BellRing, BookOpenCheck, Bot, Building2, Check, CheckCircle2, Gauge, LogIn, Map, MapPinned, Megaphone, Menu, Phone,
  ShieldAlert, ShieldCheck, Siren, Smartphone, UserRound, UsersRound, X,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useRessource } from '../api/hooks';
import { ESPACE_PAR_ROLE, useAuth } from '../auth/AuthContext';
import { Logo } from '../components/Logo';
import Photo from '../components/Photo';
import { useConfig } from '../lib/config';
import { nombre } from '../lib/format';
import { useInstallation } from '../lib/installation';

const FONCTIONS = [
  { icone: Siren, titre: 'SOS en un geste', texte: 'Votre position GPS part vers l’agent disponible de la structure de secours la plus proche. 5 secondes pour annuler.', urgence: true },
  { icone: ShieldAlert, titre: 'Signalement guidé', texte: 'Accident, incendie, inondation : en quatre étapes, avec photos et position sur la carte.' },
  { icone: BellRing, titre: 'Suivi en direct', texte: 'Chaque étape est notifiée, et vous voyez l’agent approcher jusqu’au compte rendu.' },
  { icone: Map, titre: 'Carte interactive', texte: 'Incidents récents, carte de chaleur, zones à risque et alertes officielles.' },
  { icone: MapPinned, titre: 'Services proches', texte: 'Hôpitaux, pharmacies, police et pompiers autour de vous, avec l’itinéraire.' },
  { icone: BookOpenCheck, titre: 'Premiers secours', texte: '12 fiches pratiques, consultables même sans connexion.' },
  { icone: UsersRound, titre: 'Entraide de quartier', texte: 'Confirmez ce que vous constatez et partagez une information utile.' },
  { icone: Bot, titre: 'Assistant, français et wolof', texte: 'Des conseils de prévention et une aide pour trouver le bon service.' },
];

const CONSTATS = [
  { titre: 'Plusieurs numéros, peu de repères', texte: 'Police, pompiers, santé : dans l’urgence, il faut savoir qui appeler et décrire où l’on se trouve.' },
  { titre: 'La position n’est pas transmise', texte: 'Sans coordonnées précises, les secours perdent du temps à localiser la personne en danger.' },
  { titre: 'Aucune vue d’ensemble', texte: 'Sans carte commune, il est difficile de coordonner les équipes et de repérer les zones à risque.' },
];

const ETAPES = [
  { photo: 'rue-inondee', titre: 'Vous signalez', texte: 'Un citoyen constate une rue inondée et envoie un signalement géolocalisé avec photo.' },
  { photo: 'pompiers-bnsp', titre: 'Les secours sont mobilisés', texte: 'Le citoyen choisit la structure la plus proche et un agent disponible ; l’agent accepte et part sur place.' },
  { photo: 'croix-rouge-agent', titre: 'Vous êtes informé', texte: 'Chaque étape vous est notifiée, jusqu’au compte rendu de l’intervention.' },
];

const PARCOURS = [
  { titre: 'Alerte reçue', texte: 'Le dossier arrive à la structure la plus proche et à l’agent choisi.' },
  { titre: 'Pris en charge', texte: 'Un agent accepte l’intervention.' },
  { titre: 'Secours en route', texte: 'Vous voyez l’agent approcher sur la carte.' },
  { titre: 'Résolu', texte: 'Compte rendu, puis votre évaluation.' },
];

const ESPACES = [
  { icone: UserRound, titre: 'Citoyens', texte: 'Déclencher un SOS, signaler, suivre ses dossiers et recevoir les alertes de sa région.' },
  { icone: ShieldCheck, titre: 'Agents de secours', texte: 'Recevoir les missions transmises, se déclarer disponible, intervenir, clôturer avec un compte rendu.' },
  { icone: Gauge, titre: 'Superviseurs', texte: 'Chaque structure a son superviseur : il crée ses agents, affecte ses dossiers et suit ses délais.' },
];

/** Compteur animé jusqu'à la valeur réelle (désactivé si l'utilisateur réduit les animations). */
function Compteur({ valeur }) {
  const [affiche, setAffiche] = useState(0);
  useEffect(() => {
    if (valeur == null) return undefined;
    if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) { setAffiche(valeur); return undefined; }
    let image;
    const debut = performance.now();
    const pas = (t) => {
      const p = Math.min(1, (t - debut) / 1200);
      setAffiche(Math.round(valeur * (1 - (1 - p) ** 3)));
      if (p < 1) image = requestAnimationFrame(pas);
    };
    image = requestAnimationFrame(pas);
    return () => cancelAnimationFrame(image);
  }, [valeur]);
  return valeur == null ? '…' : nombre(affiche);
}

/** Les étapes réelles d'un dossier, parcourues en boucle (immobile si l'utilisateur réduit les animations). */
function ParcoursDossier({ className }) {
  const [etape, setEtape] = useState(PARCOURS.length - 1);
  useEffect(() => {
    if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return undefined;
    setEtape(0);
    const t = setInterval(() => setEtape((e) => (e + 1) % PARCOURS.length), 2400);
    return () => clearInterval(t);
  }, []);
  return (
    <div className={clsx('rounded-3xl bg-surface p-5 text-texte shadow-flottant', className)}>
      <p className="text-xs font-bold uppercase tracking-widest text-marque-600">Le parcours d’un dossier</p>
      <ol className="mt-4">
        {PARCOURS.map((p, i) => (
          <li key={p.titre} className="relative flex gap-3 pb-3.5 last:pb-0">
            {i < PARCOURS.length - 1 && <span className={clsx('absolute bottom-0 left-[11px] top-6 w-0.5 transition-colors duration-500', i < etape ? 'bg-marque-600' : 'bg-surface-bord')} aria-hidden />}
            <span className={clsx('relative grid h-6 w-6 shrink-0 place-items-center rounded-full transition-colors duration-500',
              i <= etape ? 'bg-marque-600 text-white' : 'bg-surface-douce text-texte-pale ring-1 ring-surface-bord', i === etape && 'ring-4 ring-marque-600/20')}>
              {i < etape ? <Check className="h-3.5 w-3.5" aria-hidden /> : <span className="text-[11px] font-bold">{i + 1}</span>}
            </span>
            <div className={clsx('min-w-0 transition-opacity duration-500', i > etape && 'opacity-50')}>
              <p className="text-sm font-bold leading-6">{p.titre}</p>
              <p className="text-[13px] leading-snug text-texte-doux">{p.texte}</p>
            </div>
          </li>
        ))}
      </ol>
    </div>
  );
}

function EnTete({ espace }) {
  const [ouvert, setOuvert] = useState(false);
  const [defile, setDefile] = useState(false);
  useEffect(() => {
    const suivre = () => setDefile(window.scrollY > 24);
    suivre();
    window.addEventListener('scroll', suivre, { passive: true });
    return () => window.removeEventListener('scroll', suivre);
  }, []);
  const clair = !defile && !ouvert;
  const liens = [['#plateforme', 'La plateforme'], ['#fonctionnalites', 'Fonctionnalités'], ['#comment', 'Comment ça marche'], ['#espaces', 'Espaces']];
  return (
    <header className={clsx('fixed inset-x-0 top-0 z-[800] transition-colors duration-200', clair ? 'bg-transparent text-white' : 'border-b border-surface-bord bg-surface/95 text-texte backdrop-blur')}>
      <div className="mx-auto flex h-[72px] max-w-7xl items-center justify-between gap-4 px-4 sm:px-8">
        <Link to="/" className="flex items-center gap-2.5"><Logo className="h-10 w-10" clair={clair} /><span className="font-titre text-xl font-extrabold">SenAlert</span></Link>
        <nav className="hidden items-center gap-1 lg:flex" aria-label="Navigation de la page">
          {liens.map(([a, l]) => <a key={a} href={a} className={clsx('rounded-full px-3.5 py-2 text-sm font-semibold transition', clair ? 'text-white/85 hover:text-white' : 'text-texte-doux hover:text-texte')}>{l}</a>)}
        </nav>
        <div className="flex items-center gap-2">
          {espace ? (
            <Link to={espace} className="rounded-full bg-marque-800 px-5 py-2.5 text-sm font-bold text-white hover:bg-marque-700">Mon espace</Link>
          ) : (
            <>
              <Link to="/connexion" className={clsx('hidden rounded-full px-4 py-2.5 text-sm font-semibold sm:block', clair ? 'hover:bg-white/10' : 'hover:bg-surface-douce')}>Connexion</Link>
              <Link to="/inscription" className={clsx('rounded-full px-5 py-2.5 text-sm font-bold', clair ? 'bg-white text-marque-800 hover:bg-marque-50' : 'bg-marque-800 text-white hover:bg-marque-700')}>S’inscrire</Link>
            </>
          )}
          <button type="button" onClick={() => setOuvert((o) => !o)} className="rounded-lg p-2 lg:hidden" aria-label={ouvert ? 'Fermer le menu' : 'Ouvrir le menu'} aria-expanded={ouvert}>
            {ouvert ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
          </button>
        </div>
      </div>
      {ouvert && (
        <nav className="border-t border-surface-bord bg-surface px-4 py-3 lg:hidden" aria-label="Menu mobile">
          {liens.map(([a, l]) => <a key={a} href={a} onClick={() => setOuvert(false)} className="block rounded-xl px-3 py-2.5 font-semibold hover:bg-surface-douce">{l}</a>)}
          {!espace && <Link to="/connexion" className="block rounded-xl px-3 py-2.5 font-semibold hover:bg-surface-douce sm:hidden">Connexion</Link>}
        </nav>
      )}
    </header>
  );
}

function Titre({ surtitre, titre, texte }) {
  return (
    <div className="mx-auto max-w-2xl text-center">
      <p className="text-sm font-bold uppercase tracking-widest text-marque-600">{surtitre}</p>
      <h2 className="mt-2 font-titre text-3xl font-extrabold sm:text-4xl">{titre}</h2>
      {texte && <p className="mt-3 text-texte-doux">{texte}</p>}
    </div>
  );
}

export default function Vitrine() {
  const { utilisateur } = useAuth();
  const config = useConfig();
  const { donnees: s } = useRessource('/statistiques-publiques/');
  const { donnees: alertes } = useRessource('/alertes/zones/', { en_cours: 1 });
  const espace = utilisateur ? ESPACE_PAR_ROLE[utilisateur.role] : null;
  const installation = useInstallation();
  const chiffres = [
    ['Signalements enregistrés', s?.signalements], ['Alertes SOS reçues', s?.alertes_sos],
    ['Dossiers résolus', s?.resolus], ['Services mobilisables', s?.services],
  ];

  return (
    <div className="bg-surface-douce">
      <EnTete espace={espace} />

      {/* Héros */}
      <section className="relative overflow-hidden bg-marque-950 text-white">
        <Photo nom="ambulance-pompiers" priorite className="absolute inset-0 h-full w-full" imgClassName="object-[62%_20%]" alt="Ambulance des sapeurs-pompiers à Thiès" />
        <div className="absolute inset-0 bg-gradient-to-r from-marque-950/95 via-marque-800/85 to-marque-600/30" aria-hidden />
        <div className="relative mx-auto grid max-w-7xl items-center gap-10 px-4 pb-24 pt-32 sm:px-8 lg:grid-cols-[minmax(0,1.25fr)_minmax(0,.75fr)] lg:pb-32 lg:pt-40">
          <div>
            <p className="inline-flex items-center gap-2 rounded-full bg-white/10 px-3.5 py-1.5 text-[13px] font-semibold ring-1 ring-white/20">
              <span className="h-2 w-2 rounded-full bg-marque-100" aria-hidden /> Signalement et gestion des urgences au Sénégal
            </p>
            <h1 className="mt-6 font-titre text-[2.6rem] font-extrabold leading-[1.06] sm:text-6xl">Ensemble, protégeons des vies</h1>
            <p className="mt-5 max-w-xl text-lg leading-relaxed text-white/85">
              SenAlert relie les citoyens, les agents de secours et les superviseurs sur un même canal. Votre alerte part vers la structure la plus proche, et vous suivez chaque étape.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link to={espace || '/inscription'} className="inline-flex items-center gap-2 rounded-full bg-white px-6 py-3.5 font-bold text-marque-800 shadow-lg transition hover:bg-marque-50">
                {espace ? 'Ouvrir mon espace' : 'Créer mon compte'} <ArrowRight className="h-5 w-5" />
              </Link>
              {!espace && (
                <Link to="/connexion" className="inline-flex items-center gap-2 rounded-full px-6 py-3.5 font-bold text-white ring-1 ring-white/40 transition hover:bg-white/10">
                  <LogIn className="h-5 w-5" /> Se connecter
                </Link>
              )}
              <Link to="/simulateur" className="inline-flex items-center gap-2 rounded-full px-5 py-3.5 font-bold text-white ring-1 ring-white/40 hover:bg-white/10">
                <Smartphone className="h-5 w-5" /> Voir l’app mobile
              </Link>
            </div>
            {config.numeros_urgence.length > 0 && (
              <div className="mt-8 flex flex-wrap items-center gap-2 text-sm">
                <span className="font-semibold text-white/80">Danger immédiat ? Appelez :</span>
                {config.numeros_urgence.map((n) => <a key={n.numero} href={`tel:${n.numero}`} className="inline-flex items-center gap-1.5 rounded-full bg-white/10 px-3 py-1 font-bold ring-1 ring-white/25 hover:bg-white/20"><Phone className="h-3.5 w-3.5" />{n.service} {n.numero}</a>)}
              </div>
            )}
          </div>
          <ParcoursDossier className="hidden lg:block" />
        </div>
      </section>

      {/* Chiffres réels */}
      <section className="relative z-10 mx-auto -mt-12 max-w-6xl px-4 sm:px-8" aria-label="Chiffres de la plateforme">
        <div className="carte grid grid-cols-2 divide-surface-bord p-2 md:grid-cols-4 md:divide-x">
          {chiffres.map(([l, v]) => (
            <div key={l} className="px-4 py-4 text-center">
              <p className="font-titre text-3xl font-extrabold tabular-nums text-marque-800 sm:text-4xl"><Compteur valeur={v} /></p>
              <p className="mt-1 text-[13px] text-texte-doux">{l}</p>
            </div>
          ))}
        </div>
        <p className="mt-2 text-center text-xs text-texte-pale">
          Chiffres calculés depuis la base SenAlert{s?.donnees_demo ? ' ; elle contient actuellement des données de démonstration, qui ne sont pas des incidents réels' : ''}.
        </p>
      </section>

      {alertes?.results?.length > 0 && (
        <section className="mx-auto mt-8 max-w-6xl px-4 sm:px-8">
          <div className="flex flex-wrap items-center gap-x-6 gap-y-2 rounded-2xl border-l-4 border-or bg-or-clair px-5 py-3">
            <p className="flex items-center gap-2 font-bold"><Megaphone className="h-5 w-5" /> Alertes en cours</p>
            {alertes.results.slice(0, 3).map((a) => <p key={a.id} className="text-sm"><b>{a.titre}</b> — {a.regions_libelles.join(', ')}</p>)}
          </div>
        </section>
      )}

      {/* Présentation */}
      <section id="plateforme" className="mx-auto max-w-7xl scroll-mt-20 px-4 py-20 sm:px-8">
        <Titre surtitre="Pourquoi SenAlert" titre="Quand chaque minute compte, l’information doit circuler" texte="SenAlert réunit au même endroit le signalement, la coordination et l’analyse des urgences." />
        <div className="mt-12 grid gap-4 md:grid-cols-3">
          {CONSTATS.map((c, i) => (
            <div key={c.titre} className="carte p-6">
              <p className="font-titre text-sm font-extrabold text-marque-600">0{i + 1}</p>
              <h3 className="mt-2 text-lg font-bold">{c.titre}</h3>
              <p className="mt-1.5 text-sm leading-relaxed text-texte-doux">{c.texte}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Fonctionnalités */}
      <section id="fonctionnalites" className="scroll-mt-20 bg-surface py-20">
        <div className="mx-auto max-w-7xl px-4 sm:px-8">
          <Titre surtitre="Fonctionnalités" titre="Une seule plateforme, de l’alerte à la clôture" />
          <div className="mt-12 grid gap-px overflow-hidden rounded-3xl border border-surface-bord bg-surface-bord sm:grid-cols-2 lg:grid-cols-4">
            {FONCTIONS.map((f) => (
              <div key={f.titre} className="bg-surface p-6">
                <f.icone className={clsx('h-6 w-6', f.urgence ? 'text-sos-fonce' : 'text-marque-600')} aria-hidden />
                <h3 className="mt-4 font-bold">{f.titre}</h3>
                <p className="mt-1.5 text-sm leading-relaxed text-texte-doux">{f.texte}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Comment ça marche */}
      <section id="comment" className="mx-auto max-w-7xl scroll-mt-20 px-4 py-20 sm:px-8">
        <Titre surtitre="Comment ça marche" titre="Trois étapes, un suivi de bout en bout" texte="Scénario d’usage illustré par des photos sous licence libre : aucun incident réel n’est représenté." />
        <div className="mt-12 grid gap-6 md:grid-cols-3">
          {ETAPES.map((e, i) => (
            <article key={e.titre} className="carte overflow-hidden">
              <Photo nom={e.photo} className="h-52" alt="" />
              <div className="p-6">
                <p className="font-titre text-sm font-extrabold text-marque-600">Étape {i + 1}</p>
                <h3 className="mt-1 font-titre text-xl font-extrabold">{e.titre}</h3>
                <p className="mt-2 text-sm leading-relaxed text-texte-doux">{e.texte}</p>
              </div>
            </article>
          ))}
        </div>
      </section>

      {/* Trois espaces */}
      <section id="espaces" className="relative scroll-mt-20 overflow-hidden bg-marque-950 text-white">
        <Photo nom="pompiers-defile" className="absolute inset-0 h-full w-full opacity-25" alt="" />
        <div className="relative mx-auto grid max-w-7xl gap-12 px-4 py-20 sm:px-8 lg:grid-cols-[1fr_1.1fr] lg:items-center">
          <div>
            <p className="text-sm font-bold uppercase tracking-widest text-marque-100">Trois espaces</p>
            <h2 className="mt-2 font-titre text-3xl font-extrabold sm:text-4xl">Pensé pour ceux qui alertent et ceux qui interviennent</h2>
            <ul className="mt-6 space-y-2.5">
              {['Orientation vers la structure la plus proche', 'Délais de prise en charge mesurés', 'Score de risque descriptif par région', 'Données personnelles protégées (loi n° 2008-12)'].map((t) => (
                <li key={t} className="flex items-center gap-2.5 text-white/90"><CheckCircle2 className="h-5 w-5 shrink-0 text-succes-vif" />{t}</li>
              ))}
            </ul>
          </div>
          <div className="space-y-3">
            {ESPACES.map((e) => (
              <div key={e.titre} className="flex gap-4 rounded-2xl bg-white/[.08] p-5 ring-1 ring-white/15 backdrop-blur-sm">
                <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-white text-marque-800"><e.icone className="h-5 w-5" aria-hidden /></span>
                <div><h3 className="font-bold">{e.titre}</h3><p className="mt-0.5 text-sm text-white/80">{e.texte}</p></div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Appel à l'action */}
      <section className="mx-auto max-w-3xl px-4 py-20 text-center sm:px-8">
        <h2 className="font-titre text-3xl font-extrabold sm:text-4xl">Rejoignez SenAlert</h2>
        <p className="mx-auto mt-3 max-w-xl text-texte-doux">Disponible dans votre navigateur, sur ordinateur comme sur téléphone. L’application mobile se découvre dans le <Link to="/simulateur" className="lien">simulateur</Link>.</p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Link to={espace || '/inscription'} className="inline-flex items-center gap-2 rounded-full bg-marque-800 px-7 py-3.5 font-bold text-white hover:bg-marque-700">
            {espace ? 'Ouvrir mon espace' : 'Créer mon compte'} <ArrowRight className="h-5 w-5" />
          </Link>
          {installation.possible && !installation.ios && (
            <button type="button" onClick={installation.installer} className="inline-flex items-center gap-2 rounded-full border border-marque-600 px-7 py-3.5 font-bold text-marque-700 hover:bg-marque-50">
              <Smartphone className="h-5 w-5" /> Installer l’application
            </button>
          )}
        </div>
        {installation.ios && <p className="mt-4 text-sm text-texte-doux">Sur iPhone : touchez « Partager » puis « Sur l’écran d’accueil » pour installer SenAlert.</p>}
      </section>

      <footer className="bg-marque-950 text-white/75">
        <div className="mx-auto grid max-w-7xl gap-8 px-4 py-12 text-sm sm:px-8 md:grid-cols-[1.6fr_1fr_1fr_1fr]">
          <div>
            <p className="flex items-center gap-2.5 font-titre text-lg font-extrabold text-white"><Logo className="h-8 w-8" clair /> SenAlert</p>
            <p className="mt-3 max-w-xs leading-relaxed">Ensemble, protégeons des vies. Projet de fin de formation, ISEP Amadou Traoré de Diamniadio.</p>
          </div>
          <div>
            <p className="font-bold text-white">Plateforme</p>
            <ul className="mt-3 space-y-2">
              <li><a href="#fonctionnalites" className="hover:text-white">Fonctionnalités</a></li>
              <li><a href="#comment" className="hover:text-white">Comment ça marche</a></li>
              <li><Link to="/simulateur" className="hover:text-white">Application mobile</Link></li>
            </ul>
          </div>
          <div>
            <p className="font-bold text-white">Accès</p>
            <ul className="mt-3 space-y-2">
              <li><Link to="/connexion" className="hover:text-white">Connexion</Link></li>
              <li><Link to="/inscription" className="hover:text-white">Créer un compte</Link></li>
              <li><Link to="/connexion?espace=agent" className="inline-flex items-center gap-1.5 hover:text-white"><Building2 className="h-3.5 w-3.5" /> Espace agent</Link></li>
            </ul>
          </div>
          <div>
            <p className="font-bold text-white">Urgence</p>
            <ul className="mt-3 space-y-2">
              {config.numeros_urgence.map((n) => <li key={n.numero}><a href={`tel:${n.numero}`} className="hover:text-white">{n.service} : <b>{n.numero}</b></a></li>)}
            </ul>
          </div>
        </div>
        <div className="border-t border-white/10">
          <p className="mx-auto max-w-7xl px-4 py-4 text-xs sm:px-8">SenAlert ne remplace pas les services officiels de secours. · <Link to="/credits" className="underline hover:text-white">Crédits photos</Link></p>
        </div>
      </footer>
    </div>
  );
}
