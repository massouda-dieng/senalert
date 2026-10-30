import {
  ArrowRight, BellRing, BookOpenCheck, Bot, Check, CheckCircle2, Flame, Map, MapPinned, Megaphone, Phone, Siren,
  Smartphone, UsersRound,
} from 'lucide-react';
import clsx from 'clsx';
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useRessource } from '../api/hooks';
import { ESPACE_PAR_ROLE, useAuth } from '../auth/AuthContext';
import { BandeDrapeau, Logo } from '../components/Logo';
import Photo from '../components/Photo';
import { useConfig } from '../lib/config';
import { useInstallation } from '../lib/installation';
import { nombre } from '../lib/format';

const FONCTIONS = [
  { icone: Siren, titre: 'SOS en un geste', texte: 'Votre position GPS et sa précision sont envoyées aux agents de votre zone. 5 secondes pour annuler.', ton: 'bg-sos-clair text-sos' },
  { icone: Flame, titre: 'Signalement guidé', texte: 'Accident, incendie, inondation… en 4 étapes, avec photos et position sur la carte.', ton: 'bg-or-clair text-or-fonce' },
  { icone: BellRing, titre: 'Les secours en direct', texte: 'Chaque étape est notifiée et vous voyez l’agent approcher sur la carte, puis vous notez l’intervention.', ton: 'bg-marque-50 text-marque-700' },
  { icone: UsersRound, titre: 'Entraide de quartier', texte: 'Voyez les incidents autour de vous, confirmez ce que vous constatez, partagez une information utile.', ton: 'bg-blue-50 text-blue-700' },
  { icone: Map, titre: 'Carte interactive', texte: 'Incidents récents, carte de chaleur, zones à risque, alertes officielles et vue satellite.', ton: 'bg-emerald-50 text-emerald-700' },
  { icone: MapPinned, titre: 'Services proches', texte: 'Hôpitaux, pharmacies, police et pompiers autour de vous, avec itinéraire.', ton: 'bg-violet-50 text-violet-700' },
  { icone: BookOpenCheck, titre: 'Premiers secours', texte: '12 fiches pratiques, consultables même sans connexion.', ton: 'bg-rose-50 text-rose-700' },
  { icone: Bot, titre: 'En français et en wolof', texte: 'L’espace citoyen parle wolof, et un assistant répond aux questions de prévention.', ton: 'bg-amber-50 text-amber-700' },
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

const ETAPES = [
  { photo: 'rue-inondee', titre: '1. Vous signalez', texte: 'Un citoyen constate une rue inondée et envoie un signalement géolocalisé avec photo.' },
  { photo: 'pompiers-bnsp', titre: '2. Les secours sont mobilisés', texte: 'Le dossier arrive au service compétent de la zone ; un agent l’accepte et part sur place.' },
  { photo: 'croix-rouge-agent', titre: '3. Vous êtes informé', texte: 'Chaque étape vous est notifiée jusqu’au compte rendu de l’intervention.' },
];

const PARCOURS = [
  { titre: 'Alerte reçue', texte: 'Le dossier arrive au service de votre zone.' },
  { titre: 'Pris en charge', texte: 'Un agent accepte l’intervention.' },
  { titre: 'Secours en route', texte: 'Vous voyez l’agent approcher sur la carte.' },
  { titre: 'Résolu', texte: 'Compte rendu, puis votre évaluation.' },
];

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
    <div className={clsx('rounded-3xl border border-surface-bord bg-surface p-5 shadow-flottant', className)}>
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

export default function Vitrine() {
  const { utilisateur } = useAuth();
  const config = useConfig();
  const { donnees: s } = useRessource('/statistiques-publiques/');
  const { donnees: alertes } = useRessource('/alertes/zones/', { en_cours: 1 });
  const espace = utilisateur ? ESPACE_PAR_ROLE[utilisateur.role] : null;
  const installation = useInstallation();

  return (
    <div className="bg-surface-douce">
      {/* Barre de navigation */}
      <header className="relative z-20">
        <BandeDrapeau className="h-1" />
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-4 sm:px-8">
          <Link to="/" className="flex items-center gap-2.5"><Logo className="h-10 w-10" /><span className="font-titre text-xl font-extrabold">SenAlert</span></Link>
          <nav className="flex items-center gap-2">
            <a href="#fonctionnalites" className="hidden rounded-full px-4 py-2 text-sm font-semibold text-texte-doux hover:text-texte md:block">Fonctionnalités</a>
            <a href="#comment" className="hidden rounded-full px-4 py-2 text-sm font-semibold text-texte-doux hover:text-texte md:block">Comment ça marche</a>
            {espace ? (
              <Link to={espace} className="rounded-full bg-marque-800 px-5 py-2 text-sm font-bold text-white hover:bg-marque-700">Mon espace</Link>
            ) : (
              <>
                <Link to="/connexion" className="rounded-full px-4 py-2 text-sm font-semibold hover:bg-surface">Connexion</Link>
                <Link to="/inscription" className="rounded-full bg-marque-800 px-5 py-2 text-sm font-bold text-white hover:bg-marque-700">S’inscrire</Link>
              </>
            )}
          </nav>
        </div>
      </header>

      {/* Héros */}
      <section className="mx-auto grid max-w-7xl items-center gap-10 px-4 pb-14 pt-8 sm:px-8 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.05fr)] lg:gap-14 lg:pb-20 lg:pt-12">
        <div>
          <p className="text-sm font-bold uppercase tracking-widest text-marque-600">Plateforme citoyenne d’alerte · Sénégal</p>
          <h1 className="mt-4 font-titre text-4xl font-extrabold leading-[1.08] sm:text-[3.4rem]">
            De l’alerte à l’intervention, suivez <span className="text-marque-600">chaque étape</span>.
          </h1>
          <p className="mt-5 max-w-xl text-lg leading-relaxed text-texte-doux">
            SenAlert relie les citoyens, les agents de secours et les superviseurs. Votre SOS ou votre signalement part vers le service de votre zone, et vous voyez où en est votre dossier.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link to={espace || '/inscription'} className="inline-flex items-center gap-2 rounded-full bg-marque-800 px-6 py-3.5 font-bold text-white hover:bg-marque-700">
              {espace ? 'Ouvrir mon espace' : 'Créer mon compte'} <ArrowRight className="h-5 w-5" />
            </Link>
            <Link to="/simulateur" className="inline-flex items-center gap-2 rounded-full border border-surface-bord bg-surface px-6 py-3.5 font-bold hover:bg-surface-douce">
              <Smartphone className="h-5 w-5" /> Essayer l’app mobile
            </Link>
          </div>
          {config.numeros_urgence.length > 0 && (
            <div className="mt-8 flex flex-wrap items-center gap-2 border-t border-surface-bord pt-5 text-sm">
              <span className="font-semibold text-texte-doux">Danger immédiat ? Appelez :</span>
              {config.numeros_urgence.map((n) => <a key={n.numero} href={`tel:${n.numero}`} className="inline-flex items-center gap-1.5 rounded-full bg-sos-clair px-3 py-1 font-bold text-sos-fonce hover:bg-sos hover:text-white"><Phone className="h-3.5 w-3.5" />{n.service} {n.numero}</a>)}
            </div>
          )}
        </div>
        <div className="relative lg:pl-10">
          <Photo nom="ambulance-pompiers" priorite className="h-72 rounded-[2rem] sm:h-96 lg:h-[520px]" imgClassName="object-[62%_20%]" alt="Ambulance des sapeurs-pompiers à Thiès" />
          <ParcoursDossier className="relative mx-4 -mt-20 sm:mx-10 lg:absolute lg:bottom-8 lg:left-0 lg:mx-0 lg:mt-0 lg:w-[310px]" />
        </div>
      </section>

      {/* Chiffres réels */}
      <section className="border-y border-surface-bord bg-surface">
        <div className="mx-auto grid max-w-7xl grid-cols-2 gap-y-5 px-4 py-6 sm:px-8 md:grid-cols-4">
          {[
            ['Signalements', s?.signalements], ['Dossiers résolus', s?.resolus], ['Citoyens inscrits', s?.citoyens], ['Services mobilisables', s?.services],
          ].map(([l, v]) => (
            <div key={l} className="flex items-baseline gap-2.5">
              <p className="font-titre text-3xl font-extrabold text-marque-700"><Compteur valeur={v} /></p>
              <p className="text-sm text-texte-doux">{l}</p>
            </div>
          ))}
        </div>
      </section>
      <p className="mx-auto max-w-7xl px-4 pt-2 text-xs text-texte-pale sm:px-8">
        Chiffres calculés en direct depuis la base SenAlert{s?.donnees_demo ? ' — elle contient actuellement des données de démonstration' : ''}.
      </p>

      {/* Alertes officielles en cours */}
      {alertes?.results?.length > 0 && (
        <section className="mx-auto mt-8 max-w-6xl px-4 sm:px-8"><div className="rounded-2xl border-l-4 border-or-vif bg-or-clair">
          <div className="mx-auto flex max-w-7xl flex-wrap items-center gap-x-6 gap-y-2 px-4 py-3 sm:px-8">
            <p className="flex items-center gap-2 font-bold"><Megaphone className="h-5 w-5" /> Alertes en cours</p>
            {alertes.results.slice(0, 3).map((a) => <p key={a.id} className="text-sm"><b>{a.titre}</b> — {a.regions_libelles.join(', ')}</p>)}
          </div>
        </div></section>
      )}

      {/* Fonctionnalités */}
      <section id="fonctionnalites" className="mx-auto max-w-7xl px-4 py-20 sm:px-8">
        <div className="mx-auto max-w-2xl text-center">
          <p className="text-sm font-bold uppercase tracking-widest text-marque-600">Tout en un</p>
          <h2 className="mt-2 font-titre text-3xl font-extrabold sm:text-4xl">Une seule application pour toutes les urgences</h2>
          <p className="mt-3 text-texte-doux">Accidents, incendies, inondations, agressions, pannes électriques : SenAlert réunit citoyens, secouristes et superviseurs.</p>
        </div>
        <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {FONCTIONS.map((f) => (
            <div key={f.titre} className="carte p-5 transition hover:-translate-y-1 hover:shadow-flottant">
              <div className={`inline-flex rounded-2xl p-3 ${f.ton}`}><f.icone className="h-6 w-6" /></div>
              <h3 className="mt-4 text-lg font-bold">{f.titre}</h3>
              <p className="mt-1.5 text-sm text-texte-doux">{f.texte}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Comment ça marche */}
      <section id="comment" className="bg-surface py-20">
        <div className="mx-auto max-w-7xl px-4 sm:px-8">
          <h2 className="text-center font-titre text-3xl font-extrabold sm:text-4xl">Comment ça marche</h2>
          <p className="mt-2 text-center text-sm text-texte-pale">Scénario d’usage illustré par des photos libres de droits (aucun incident réel représenté).</p>
          <div className="mt-12 grid gap-6 md:grid-cols-3">
            {ETAPES.map((e) => (
              <article key={e.titre} className="overflow-hidden rounded-3xl bg-surface-douce">
                <Photo nom={e.photo} className="h-56" alt="" />
                <div className="p-6">
                  <h3 className="font-titre text-xl font-extrabold text-marque-700">{e.titre}</h3>
                  <p className="mt-2 text-texte-doux">{e.texte}</p>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      {/* Bandeau services */}
      <section className="relative overflow-hidden">
        <Photo nom="pompiers-defile" className="absolute inset-0 h-full w-full" alt="" />
        <div className="absolute inset-0 bg-black/70" aria-hidden />
        <div className="relative mx-auto grid max-w-7xl gap-10 px-4 py-20 text-white sm:px-8 lg:grid-cols-2 lg:items-center">
          <div>
            <h2 className="font-titre text-3xl font-extrabold sm:text-4xl">Pensé avec les services de secours</h2>
            <p className="mt-4 text-white/85">Chaque signalement est orienté vers le service compétent — sapeurs-pompiers, police, santé, SENELEC, ONAS — dans la bonne région. Les superviseurs suivent les délais, la carte des risques et la qualité des données.</p>
            <ul className="mt-6 space-y-2">
              {['Affectation au bon service et à la bonne zone', 'Délais de prise en charge mesurés', 'Score de risque par région', 'Données personnelles protégées (loi 2008-12)'].map((t) => (
                <li key={t} className="flex items-center gap-2"><CheckCircle2 className="h-5 w-5 text-or" />{t}</li>
              ))}
            </ul>
          </div>
          <Photo nom="croix-rouge-equipe" className="h-72 rounded-3xl" alt="Croix-Rouge du Sénégal" />
        </div>
      </section>

      {/* Appel à l'action */}
      <section className="mx-auto max-w-5xl px-4 py-20 text-center sm:px-8">
        <Smartphone className="mx-auto h-12 w-12 text-marque-600" />
        <h2 className="mt-4 font-titre text-3xl font-extrabold">Rejoignez SenAlert</h2>
        <p className="mx-auto mt-3 max-w-xl text-texte-doux">Disponible dès maintenant dans votre navigateur, sur ordinateur comme sur téléphone. Les applications Android et iOS sont en préparation : essayez-les dès maintenant dans le <Link to="/simulateur" className="lien">simulateur mobile</Link>.</p>
<div className="mt-8 flex flex-wrap justify-center gap-3">
        <Link to={espace || '/inscription'} className="inline-flex items-center gap-2 rounded-full bg-marque-600 px-7 py-3.5 font-bold text-white shadow-lg hover:bg-marque-700">
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

      <footer className="bg-marque-950 text-white/70">
        <BandeDrapeau className="h-1" />
        <div className="mx-auto flex max-w-7xl flex-col gap-4 px-4 py-8 text-sm sm:flex-row sm:items-center sm:justify-between sm:px-8">
          <p className="flex items-center gap-2"><Logo className="h-7 w-7" clair /> SenAlert — projet de fin de formation, ISEP Amadou Traoré de Diamniadio.</p>
          <p>SenAlert ne remplace pas les services officiels de secours. · <Link to="/credits" className="underline hover:text-white">Crédits photos</Link></p>
        </div>
      </footer>
    </div>
  );
}
