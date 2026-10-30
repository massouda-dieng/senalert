import clsx from 'clsx';
import { BookOpenCheck, Bot, ChevronRight, Crosshair, FolderOpen, Map, MapPinned, Phone, RotateCcw, ShieldAlert, Siren, X } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, nouvelleCle } from '../../api/client';
import { useRessource } from '../../api/hooks';
import { useAuth } from '../../auth/AuthContext';
import { BadgeStatut, Bandeau, Bouton, Carte, Chargement, Fenetre } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { ilYa } from '../../lib/format';

const COMPTE_A_REBOURS = 5;

/** Position du navigateur, avec précision. Ne bloque jamais l'envoi du SOS. */
export function lirePosition({ delai = 10000 } = {}) {
  return new Promise((resoudre) => {
    if (!navigator.geolocation) { resoudre({ erreur: 'La géolocalisation n’est pas disponible sur cet appareil.' }); return; }
    navigator.geolocation.getCurrentPosition(
      (p) => resoudre({ lat: p.coords.latitude, lng: p.coords.longitude, precision: p.coords.accuracy }),
      (e) => resoudre({ erreur: e.code === 1 ? 'Accès à la position refusé. Vous pouvez l’autoriser dans les réglages du navigateur.' : 'Position introuvable pour le moment.' }),
      { enableHighAccuracy: true, timeout: delai, maximumAge: 30000 },
    );
  });
}

function SOS() {
  const config = useConfig();
  const [etape, setEtape] = useState(null); // null | decompte | envoi | succes | echec
  const [reste, setReste] = useState(COMPTE_A_REBOURS);
  const [position, setPosition] = useState(null);
  const [resultat, setResultat] = useState(null);
  const [erreur, setErreur] = useState(null);
  const cle = useRef(null);
  const minuteur = useRef(null);
  const suivi = useRessource(resultat ? `/alertes/sos/${resultat.id}/` : null, null, { intervalle: 10000, actif: Boolean(resultat) });

  const envoyer = async (pos) => {
    setEtape('envoi');
    setErreur(null);
    const corps = { client_request_id: cle.current };
    if (pos?.lat != null) Object.assign(corps, { latitude: pos.lat, longitude: pos.lng, precision_gps: Math.round(pos.precision) });
    try {
      const r = await api('/alertes/sos/', { methode: 'POST', corps });
      setResultat(r);
      setEtape('succes');
    } catch (e) {
      setErreur(e);
      setEtape('echec');
    }
  };

  const demarrer = () => {
    cle.current = nouvelleCle(); // même clé pour toutes les tentatives de cette alerte
    setResultat(null);
    setPosition({ enCours: true });
    setReste(COMPTE_A_REBOURS);
    setEtape('decompte');
    lirePosition().then(setPosition);
  };

  useEffect(() => {
    if (etape !== 'decompte') return undefined;
    minuteur.current = setInterval(() => setReste((r) => r - 1), 1000);
    return () => clearInterval(minuteur.current);
  }, [etape]);

  useEffect(() => {
    if (etape === 'decompte' && reste <= 0) {
      clearInterval(minuteur.current);
      envoyer(position?.enCours ? null : position);
    }
  }, [reste, etape]); // eslint-disable-line react-hooks/exhaustive-deps

  const fermer = () => { clearInterval(minuteur.current); setEtape(null); };
  const dossier = suivi.donnees || resultat;

  return (
    <>
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-nuit-950 via-nuit-900 to-nuit-700 p-6 text-white sm:p-8">
        <div className="absolute -right-16 -top-16 h-64 w-64 rounded-full bg-sos/20 blur-3xl" aria-hidden />
        <div className="relative flex flex-col items-center gap-6 sm:flex-row sm:justify-between">
          <div className="max-w-md text-center sm:text-left">
            <p className="text-sm font-semibold uppercase tracking-widest text-white/60">Urgence</p>
            <h2 className="mt-1 font-titre text-3xl font-extrabold">Besoin d’aide immédiate ?</h2>
            <p className="mt-2 text-sm text-white/70">Le SOS enregistre votre position et prévient les agents SenAlert de votre zone. Pour un danger vital, appelez aussi directement les secours.</p>
            <div className="mt-4 flex flex-wrap justify-center gap-2 sm:justify-start">
              {config.numeros_urgence.map((n) => (
                <a key={n.numero} href={`tel:${n.numero}`} className="inline-flex items-center gap-1.5 rounded-full bg-white/10 px-3.5 py-1.5 text-sm font-semibold ring-1 ring-white/20 hover:bg-white/20">
                  <Phone className="h-3.5 w-3.5" /> {n.service} {n.numero}
                </a>
              ))}
            </div>
          </div>
          <button type="button" onClick={demarrer} disabled={etape === 'envoi'}
            className="grid h-40 w-40 shrink-0 animate-pulsation place-items-center rounded-full bg-gradient-to-br from-rose-500 to-sos-fonce font-titre text-4xl font-extrabold tracking-wider shadow-[0_10px_40px_rgba(225,29,72,.5)] ring-8 ring-white/10 transition hover:scale-[1.03] focus-visible:ring-white"
            aria-label="Déclencher une alerte SOS">
            <span className="flex flex-col items-center gap-1"><Siren className="h-9 w-9" />SOS</span>
          </button>
        </div>
      </div>

      <Fenetre ouverte={Boolean(etape)} onFermer={etape === 'envoi' ? () => {} : fermer} titre={etape === 'succes' ? 'Alerte enregistrée' : 'Alerte SOS'}>
        {etape === 'decompte' && (
          <div className="text-center">
            <p className="text-sm text-texte-doux">Envoi automatique dans</p>
            <p className="my-2 font-titre text-7xl font-extrabold text-sos tabular-nums" aria-live="assertive">{reste}</p>
            <PositionInfo position={position} />
            <div className="mt-6 grid grid-cols-2 gap-3">
              <Bouton variante="secondaire" taille="lg" icone={X} onClick={fermer}>Annuler</Bouton>
              <Bouton variante="danger" taille="lg" onClick={() => { clearInterval(minuteur.current); envoyer(position?.enCours ? null : position); }}>Envoyer maintenant</Bouton>
            </div>
          </div>
        )}
        {etape === 'envoi' && <Chargement texte="Transmission de l’alerte au serveur…" />}
        {etape === 'succes' && dossier && (
          <div className="space-y-4">
            <Bandeau type="succes" titre={`Dossier ${dossier.reference}`}>
              {resultat.deja_enregistree ? 'Cette alerte avait déjà été reçue : voici son suivi.' : 'Votre alerte est enregistrée par SenAlert et transmise aux agents de votre zone.'}
            </Bandeau>
            <div className="flex items-center justify-between rounded-2xl border border-surface-bord p-3">
              <span className="text-sm text-texte-doux">Statut actuel</span><BadgeStatut statut={dossier.statut} />
            </div>
            {dossier.latitude == null && <Bandeau type="alerte">Votre position n’a pas pu être jointe. Indiquez votre lieu exact aux secours par téléphone.</Bandeau>}
            <p className="text-xs text-texte-doux">Tant qu’un agent n’a pas pris en charge l’alerte, aucune intervention n’est garantie. Si le danger est immédiat, appelez directement {config.numeros_urgence.map((n) => n.numero).join(' ou ')}.</p>
            <Link to={`/citoyen/dossiers?type=sos&dossier=${dossier.id}`} className="lien text-sm">Suivre le dossier →</Link>
          </div>
        )}
        {etape === 'echec' && (
          <div className="space-y-4">
            <Bandeau type="danger" titre="L’alerte n’a PAS été transmise">{erreur?.detail}</Bandeau>
            <p className="text-sm">Appelez immédiatement les secours :</p>
            <div className="grid grid-cols-2 gap-2">
              {config.numeros_urgence.map((n) => <a key={n.numero} href={`tel:${n.numero}`} className="rounded-xl bg-sos px-3 py-3 text-center font-bold text-white">{n.service} · {n.numero}</a>)}
            </div>
            <Bouton variante="secondaire" className="w-full" icone={RotateCcw} onClick={() => envoyer(position?.enCours ? null : position)}>Réessayer l’envoi</Bouton>
          </div>
        )}
      </Fenetre>
    </>
  );
}

function PositionInfo({ position }) {
  if (!position || position.enCours) return <p className="text-sm text-texte-doux"><Crosshair className="mr-1 inline h-4 w-4 animate-spin" /> Recherche de votre position…</p>;
  if (position.erreur) return <p className="text-sm text-amber-800">{position.erreur} L’alerte sera envoyée sans position.</p>;
  return (
    <p className={clsx('text-sm', position.precision > 100 ? 'text-amber-800' : 'text-emerald-700')}>
      Position obtenue · précision ± {Math.round(position.precision)} m{position.precision > 100 && ' (approximative)'}
    </p>
  );
}

const ACTIONS = [
  { a: '/citoyen/signaler', libelle: 'Signaler un incident', texte: 'Accident, incendie, inondation…', icone: ShieldAlert, ton: 'bg-alerte-clair text-amber-700' },
  { a: '/citoyen/dossiers', libelle: 'Mes dossiers', texte: 'Suivre mes signalements', icone: FolderOpen, ton: 'bg-nuit-50 text-nuit-700' },
  { a: '/citoyen/carte', libelle: 'Carte', texte: 'Incidents récents', icone: Map, ton: 'bg-sky-50 text-sky-700' },
  { a: '/citoyen/services', libelle: 'Services proches', texte: 'Hôpitaux, pharmacies…', icone: MapPinned, ton: 'bg-succes-clair text-emerald-700' },
  { a: '/citoyen/secours', libelle: 'Premiers secours', texte: 'Fiches hors ligne', icone: BookOpenCheck, ton: 'bg-rose-50 text-rose-700' },
  { a: '/citoyen/assistant', libelle: 'Assistant', texte: 'Questions et prévention', icone: Bot, ton: 'bg-violet-50 text-violet-700' },
];

export default function Accueil() {
  const { utilisateur } = useAuth();
  const incidents = useRessource('/incidents/', { taille: 4 });
  const sos = useRessource('/alertes/sos/', { taille: 3, actifs: true });
  const recents = [...(sos.donnees?.results || []).map((d) => ({ ...d, sos: true })), ...(incidents.donnees?.results || [])].slice(0, 5);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-extrabold">Bonjour {utilisateur.first_name || ''} 👋</h1>
        <p className="text-sm text-texte-doux">Que souhaitez-vous faire ?</p>
      </div>
      <SOS />
      <div className="grid grid-cols-1 gap-3 min-[420px]:grid-cols-2 md:grid-cols-3">
        {ACTIONS.map((a) => (
          <Link key={a.a} to={a.a} className="carte group flex items-center gap-3 p-4 transition hover:-translate-y-0.5 hover:shadow-flottant">
            <div className={clsx('rounded-2xl p-3', a.ton)}><a.icone className="h-6 w-6" /></div>
            <div className="min-w-0"><p className="font-semibold">{a.libelle}</p><p className="truncate text-xs text-texte-doux">{a.texte}</p></div>
            <ChevronRight className="ml-auto hidden h-4 w-4 text-texte-pale transition group-hover:translate-x-0.5 sm:block" />
          </Link>
        ))}
      </div>
      <Carte titre="Mes derniers dossiers" action={<Link to="/citoyen/dossiers" className="lien text-sm">Tout voir</Link>} corpsClassName="p-0">
        {incidents.chargement && !incidents.donnees ? <Chargement /> : recents.length === 0 ? (
          <p className="p-5 text-sm text-texte-doux">Aucun signalement pour l’instant.</p>
        ) : (
          <ul className="divide-y divide-surface-bord">
            {recents.map((d) => (
              <li key={`${d.sos ? 's' : 'i'}${d.id}`}>
                <Link to={`/citoyen/dossiers?${d.sos ? 'type=sos&' : ''}dossier=${d.id}`} className="flex items-center justify-between gap-3 px-5 py-3 hover:bg-surface-douce">
                  <div className="min-w-0">
                    <p className="font-mono text-[13px] font-semibold text-nuit-700">{d.reference}</p>
                    <p className="truncate text-sm">{d.sos ? 'Alerte SOS' : d.categorie_libelle} · {ilYa(d.date_creation)}</p>
                  </div>
                  <BadgeStatut statut={d.statut} />
                </Link>
              </li>
            ))}
          </ul>
        )}
      </Carte>
    </div>
  );
}
