import {
  ArrowRight, BellRing, BookOpenCheck, Bot, CheckCircle2, Flame, Map, MapPinned, Megaphone, Phone, ShieldCheck, Siren,
  Smartphone, UsersRound,
} from 'lucide-react';
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
      <header className="absolute inset-x-0 top-0 z-20">
        <BandeDrapeau className="h-1" />
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-4 sm:px-8">
          <Link to="/" className="flex items-center gap-2.5 text-white"><Logo className="h-10 w-10" clair /><span className="font-titre text-xl font-extrabold">SenAlert</span></Link>
          <nav className="flex items-center gap-2">
            <a href="#fonctionnalites" className="hidden rounded-full px-4 py-2 text-sm font-semibold text-white/90 hover:bg-white/10 md:block">Fonctionnalités</a>
            <a href="#comment" className="hidden rounded-full px-4 py-2 text-sm font-semibold text-white/90 hover:bg-white/10 md:block">Comment ça marche</a>
            <Link to="/simulateur" className="hidden rounded-full px-4 py-2 text-sm font-semibold text-white/90 hover:bg-white/10 md:block">Essayer l’app mobile</Link>
            {espace ? (
              <Link to={espace} className="rounded-full bg-surface px-5 py-2 text-sm font-bold text-marque-800 hover:bg-marque-50">Mon espace</Link>
            ) : (
              <>
                <Link to="/connexion" className="rounded-full px-4 py-2 text-sm font-semibold text-white hover:bg-white/10">Connexion</Link>
                <Link to="/inscription" className="rounded-full bg-surface px-5 py-2 text-sm font-bold text-marque-800 hover:bg-marque-50">S’inscrire</Link>
              </>
            )}
          </nav>
        </div>
      </header>

      {/* Héros */}
      <section className="relative min-h-[640px] overflow-hidden lg:min-h-[720px]">
        <Photo nom="dakar-coucher-soleil" priorite className="absolute inset-0 h-full w-full" imgClassName="animate-zoomLent" alt="Coucher de soleil sur Dakar" />
        <div className="absolute inset-0 bg-gradient-to-r from-black/85 via-black/55 to-black/10" aria-hidden />
        <div className="relative mx-auto flex max-w-7xl flex-col gap-10 px-4 pb-20 pt-36 sm:px-8 lg:flex-row lg:items-center lg:pt-44">
          <div className="max-w-2xl text-white">
            <p className="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-xs font-semibold uppercase tracking-widest text-or ring-1 ring-white/20">
              <ShieldCheck className="h-4 w-4" /> Plateforme citoyenne d’alerte — Sénégal
            </p>
            <h1 className="mt-5 font-titre text-4xl font-extrabold leading-[1.1] sm:text-6xl">
              Ensemble, <span className="text-or">protégeons</span> nos quartiers.
            </h1>
            <p className="mt-5 max-w-xl text-lg text-white/85">
              Signalez une urgence en quelques secondes, suivez l’intervention des secours et restez informé des alertes de votre région — sur un seul canal.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link to={espace || '/inscription'} className="inline-flex items-center gap-2 rounded-full bg-marque-600 px-6 py-3.5 font-bold text-white shadow-lg shadow-marque-600/30 hover:bg-marque-500">
                {espace ? 'Ouvrir mon espace' : 'Créer mon compte gratuit'} <ArrowRight className="h-5 w-5" />
              </Link>
              <Link to={espace ? `${espace}` : '/connexion'} className="inline-flex items-center gap-2 rounded-full bg-sos px-6 py-3.5 font-bold text-white shadow-lg hover:bg-sos-fonce">
                <Siren className="h-5 w-5" /> Alerte SOS
              </Link>
            </div>
            {config.numeros_urgence.length > 0 && (
              <p className="mt-6 flex flex-wrap items-center gap-2 text-sm text-white/80">
                Danger immédiat ? Appelez :
                {config.numeros_urgence.map((n) => <a key={n.numero} href={`tel:${n.numero}`} className="inline-flex items-center gap-1 rounded-full bg-white/15 px-3 py-1 font-bold text-white hover:bg-white/25"><Phone className="h-3.5 w-3.5" />{n.service} {n.numero}</a>)}
              </p>
            )}
          </div>
          {/* Aperçu téléphone */}
          <div className="mx-auto hidden w-[290px] shrink-0 rotate-2 rounded-[2.6rem] bg-marque-950 p-3 shadow-2xl ring-4 ring-white/10 lg:block">
            <div className="overflow-hidden rounded-[2rem] bg-surface-douce">
              <div className="bg-gradient-to-br from-marque-700 to-marque-900 px-5 pb-8 pt-7 text-white">
                <p className="text-xs text-white/70">Bonjour Awa</p>
                <p className="font-titre text-lg font-extrabold">Besoin d’aide ?</p>
                <div className="mx-auto mt-5 grid h-28 w-28 animate-pulsation place-items-center rounded-full bg-sos font-titre text-2xl font-extrabold">SOS</div>
              </div>
              <div className="space-y-2 p-4">
                {[['Inondation', 'En cours', 'bg-amber-100 text-amber-800'], ['Accident', 'Résolu', 'bg-emerald-100 text-emerald-800']].map(([t, st, c]) => (
                  <div key={t} className="flex items-center justify-between rounded-2xl bg-surface p-3 text-xs shadow-sm"><span className="font-semibold">{t}</span><span className={`rounded-full px-2 py-0.5 font-bold ${c}`}>{st}</span></div>
                ))}
                <p className="pt-1 text-center text-[10px] text-texte-pale">Aperçu de l’interface</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Chiffres réels */}
      <section className="relative z-10 mx-auto -mt-12 max-w-6xl px-4 sm:px-8">
        <div className="grid grid-cols-2 gap-px overflow-hidden rounded-3xl bg-surface-bord shadow-flottant md:grid-cols-4">
          {[
            ['Signalements', s?.signalements], ['Dossiers résolus', s?.resolus], ['Citoyens inscrits', s?.citoyens], ['Services mobilisables', s?.services],
          ].map(([l, v]) => (
            <div key={l} className="bg-surface p-6 text-center">
              <p className="font-titre text-3xl font-extrabold text-marque-700 sm:text-4xl"><Compteur valeur={v} /></p>
              <p className="mt-1 text-sm text-texte-doux">{l}</p>
            </div>
          ))}
        </div>
        <p className="mt-2 text-center text-xs text-texte-pale">
          Chiffres calculés en direct depuis la base SenAlert{s?.donnees_demo ? ' — elle contient actuellement des données de démonstration' : ''}.
        </p>
      </section>

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
          <div className="grid grid-cols-2 gap-4">
            <Photo nom="ambulance-pompiers" className="h-48 rounded-3xl" alt="Ambulance des sapeurs-pompiers" />
            <Photo nom="croix-rouge-equipe" className="mt-8 h-48 rounded-3xl" alt="Croix-Rouge du Sénégal" />
          </div>
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
