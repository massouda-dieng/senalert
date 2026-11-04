import clsx from 'clsx';
import {
  BookOpenCheck, Bot, ChevronRight, Crosshair, Map, MapPinned, Phone, RotateCcw, ShieldAlert, ShieldCheck, Siren, X,
} from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, nouvelleCle } from '../../api/client';
import { useRessource } from '../../api/hooks';
import { useAuth } from '../../auth/AuthContext';
import CarteSenAlert, { CENTRE_SENEGAL } from '../../components/Carte';
import Photo from '../../components/Photo';
import { BadgeStatut, Bandeau, Bouton, Carte, Chargement, Fenetre, IconeNotification } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { dateHeure, ilYa } from '../../lib/format';
import { libelleCategorie, useLangue } from '../../lib/langue';
import { COULEURS } from '../../lib/couleurs';

const COMPTE_A_REBOURS = 5;
// Type d'urgence facultatif (mêmes codes que le serveur) : un clic envoie aussitôt vers le service concerné.
const TYPES_URGENCE = [
  ['medicale', 'Urgence médicale'], ['incendie', 'Incendie'], ['accident', 'Accident'], ['agression', 'Agression ou danger'],
];

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
  const { t } = useLangue();
  const [etape, setEtape] = useState(null); // null | decompte | envoi | succes | echec
  const [reste, setReste] = useState(COMPTE_A_REBOURS);
  const [position, setPosition] = useState(null);
  const [resultat, setResultat] = useState(null);
  const [erreur, setErreur] = useState(null);
  const cle = useRef(null);
  const minuteur = useRef(null);
  const suivi = useRessource(resultat ? `/alertes/sos/${resultat.id}/` : null, null, { intervalle: 10000, actif: Boolean(resultat) });

  const envoi = useRef(false);
  const envoyer = async (pos, typeUrgence = 'non_precise') => {
    if (envoi.current) return; // un seul envoi à la fois (double clic, fin du compte à rebours)
    envoi.current = true;
    clearInterval(minuteur.current);
    setEtape('envoi');
    setErreur(null);
    const corps = { client_request_id: cle.current, type_urgence: typeUrgence };
    if (pos?.lat != null) Object.assign(corps, { latitude: pos.lat, longitude: pos.lng, precision_gps: Math.round(pos.precision) });
    try {
      const r = await api('/alertes/sos/', { methode: 'POST', corps });
      setResultat(r);
      setEtape('succes');
    } catch (e) {
      setErreur(e);
      setEtape('echec');
    } finally { envoi.current = false; }
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
      <div className="relative overflow-hidden rounded-3xl text-white">
        <Photo nom="dakar-vue" className="absolute inset-0 h-full w-full" alt="" credit={false} />
        <div className="absolute inset-0 bg-gradient-to-r from-marque-950/95 via-marque-900/80 to-marque-900/40" aria-hidden />
        <div className="relative flex flex-col items-center gap-6 p-6 sm:flex-row sm:justify-between sm:p-8">
          <div className="max-w-md text-center sm:text-left">
            <p className="text-sm font-semibold uppercase tracking-widest text-white/75">{t('Urgence')}</p>
            <h2 className="mt-1 font-titre text-3xl font-extrabold">{t('Besoin d’aide immédiate ?')}</h2>
            <p className="mt-2 text-sm text-white/80">{t('Le SOS enregistre votre position et prévient les agents SenAlert de votre zone. Pour un danger vital, appelez aussi directement les secours.')}</p>
            <div className="mt-4 flex flex-wrap justify-center gap-2 sm:justify-start">
              {config.numeros_urgence.map((n) => (
                <a key={n.numero} href={`tel:${n.numero}`} className="inline-flex items-center gap-1.5 rounded-full bg-white/15 px-3.5 py-1.5 text-sm font-semibold ring-1 ring-white/25 hover:bg-white/25">
                  <Phone className="h-3.5 w-3.5" /> {n.service} {n.numero}
                </a>
              ))}
            </div>
          </div>
          <button type="button" onClick={demarrer} disabled={etape === 'envoi'}
            className="grid h-40 w-40 shrink-0 animate-pulsation place-items-center rounded-full bg-sos font-titre text-4xl font-extrabold tracking-wider shadow-[0_10px_40px_rgba(230,57,70,.55)] ring-8 ring-white/10 transition hover:scale-[1.03] hover:bg-sos-fonce focus-visible:ring-white"
            aria-label={t('Déclencher une alerte SOS')}>
            <span className="flex flex-col items-center gap-1"><Siren className="h-9 w-9" />SOS</span>
          </button>
        </div>
      </div>

      <Fenetre ouverte={Boolean(etape)} onFermer={etape === 'envoi' ? () => {} : fermer} titre={etape === 'succes' ? t('Alerte enregistrée') : t('Alerte SOS')}>
        {etape === 'decompte' && (
          <div className="text-center">
            <p className="text-sm text-texte-doux">{t('Envoi automatique dans')}</p>
            <p className="my-2 font-titre text-7xl font-extrabold text-sos-fonce tabular-nums" aria-live="assertive">{reste}</p>
            <PositionInfo position={position} />
            <p className="mt-5 text-sm font-semibold">{t('Quelle urgence ? (facultatif, envoie aussitôt)')}</p>
            <div className="mt-2 grid grid-cols-2 gap-2">
              {TYPES_URGENCE.map(([code, libelle]) => (
                <Bouton key={code} variante="secondaire" onClick={() => envoyer(position?.enCours ? null : position, code)}>{t(libelle)}</Bouton>
              ))}
            </div>
            <div className="mt-4 grid grid-cols-2 gap-3">
              <Bouton variante="secondaire" taille="lg" icone={X} onClick={fermer}>{t('Annuler')}</Bouton>
              <Bouton variante="danger" taille="lg" onClick={() => { clearInterval(minuteur.current); envoyer(position?.enCours ? null : position); }}>{t('Envoyer maintenant')}</Bouton>
            </div>
          </div>
        )}
        {etape === 'envoi' && <Chargement texte={t('Transmission de l’alerte au serveur…')} />}
        {etape === 'succes' && dossier && (
          <div className="space-y-4">
            <Bandeau type="succes" titre={`Dossier ${dossier.reference}`}>
              {resultat.deja_enregistree ? 'Cette alerte avait déjà été reçue : voici son suivi.'
                : dossier.statut === 'affecte' ? 'Un agent de la structure ci-dessous a été prévenu.' : 'Le superviseur de la structure ci-dessous a été prévenu.'}
            </Bandeau>
            <dl className="divide-y divide-surface-bord rounded-2xl border border-surface-bord text-sm">
              <div className="flex items-center justify-between px-3 py-2"><dt className="text-texte-doux">{t('Statut')}</dt><dd><BadgeStatut statut={dossier.statut} /></dd></div>
              {[
                ['Urgence', dossier.type_urgence_libelle || 'Non précisée'],
                ['Envoyée le', dateHeure(dossier.date_creation)],
                ['Position', dossier.latitude != null ? `${dossier.latitude.toFixed(5)}, ${dossier.longitude.toFixed(5)}${dossier.precision_gps != null ? ` (± ${Math.round(dossier.precision_gps)} m)` : ''}` : 'Non jointe'],
                ['Destinataire', dossier.structure_nom || 'Supervision SenAlert'],
              ].map(([k, v]) => <div key={k} className="grid grid-cols-[110px_1fr] gap-3 px-3 py-2"><dt className="text-texte-doux">{t(k)}</dt><dd className="font-medium">{v}</dd></div>)}
            </dl>
            {dossier.latitude == null && <Bandeau type="alerte">Votre position n’a pas pu être jointe. Indiquez votre lieu exact aux secours par téléphone.</Bandeau>}
            <p className="text-xs text-texte-doux">Tant qu’un agent n’a pas pris en charge l’alerte, aucune intervention n’est garantie. Si le danger est immédiat, appelez directement {config.numeros_urgence.map((n) => n.numero).join(' ou ')}.</p>
            <div className="flex flex-wrap gap-4 text-sm">
              <Link to={`/citoyen/dossiers?type=sos&dossier=${dossier.id}`} className="lien">{t('Voir le détail de l’alerte →')}</Link>
              <Link to="/citoyen/dossiers?type=sos" className="lien">{t('Historique de mes SOS')}</Link>
            </div>
          </div>
        )}
        {etape === 'echec' && (
          <div className="space-y-4">
            <Bandeau type="danger" titre={t('L’alerte n’a PAS été transmise')}>{erreur?.detail}</Bandeau>
            <p className="text-sm">{t('Appelez immédiatement les secours :')}</p>
            <div className="grid grid-cols-2 gap-2">
              {config.numeros_urgence.map((n) => <a key={n.numero} href={`tel:${n.numero}`} className="rounded-xl bg-sos-fonce px-3 py-3 text-center font-bold text-white">{n.service} · {n.numero}</a>)}
            </div>
            <Bouton variante="secondaire" className="w-full" icone={RotateCcw} onClick={() => envoyer(position?.enCours ? null : position)}>{t('Réessayer l’envoi')}</Bouton>
            {config.sms_secours && (
              <a className="flex w-full items-center justify-center gap-2 rounded-xl border border-surface-bord px-4 py-2.5 text-sm font-semibold hover:bg-surface-douce"
                href={`sms:${config.sms_secours}?&body=${encodeURIComponent(`SOS SenAlert${position?.lat != null ? ` - position ${position.lat.toFixed(5)},${position.lng.toFixed(5)} (±${Math.round(position.precision)} m) https://maps.google.com/?q=${position.lat},${position.lng}` : ' - position inconnue'}`)}`}>
                {t('Envoyer le SOS par SMS (sans internet)')}
              </a>
            )}
          </div>
        )}
      </Fenetre>
    </>
  );
}

function PositionInfo({ position }) {
  const { t } = useLangue();
  if (!position || position.enCours) return <p className="text-sm text-texte-doux"><Crosshair className="mr-1 inline h-4 w-4 animate-spin" /> {t('Recherche de votre position…')}</p>;
  if (position.erreur) return <p className="text-sm text-alerte">{t(position.erreur)} {t('L’alerte sera envoyée sans position.')}</p>;
  return (
    <p className={clsx('text-sm', position.precision > 100 ? 'text-alerte' : 'text-succes')}>
      {t('Position obtenue · précision ± {m} m', { m: Math.round(position.precision) })}{position.precision > 100 && ' (approximative)'}
    </p>
  );
}

const ACTIONS = [
  { a: '/citoyen/signaler', titre: 'Signaler un incident', texte: 'Accident, incendie, inondation…', icone: ShieldAlert, principal: true },
  { a: '/citoyen/carte', titre: 'Carte interactive', texte: 'Incidents et alertes', icone: Map },
  { a: '/citoyen/services', titre: 'Services proches', texte: 'Hôpitaux, pharmacies…', icone: MapPinned },
  { a: '/citoyen/assistant', titre: 'Assistant', texte: 'Questions, prévention', icone: Bot },
];

const ETAPES_SUIVI = [['nouveau', 'Reçu'], ['affecte', 'Affecté'], ['accepte', 'Pris en charge'], ['en_cours', 'En cours'], ['resolu', 'Résolu']];

/** Progression d'un dossier ; un dossier rejeté ou annulé garde son badge, sans fausse progression. */
function Progression({ statut }) {
  const { t } = useLangue();
  const rang = ETAPES_SUIVI.findIndex(([code]) => code === statut);
  if (rang < 0) return null;
  return (
    <ol className="mt-2 flex items-center gap-1" aria-label={`${t('Étape')} ${rang + 1} / ${ETAPES_SUIVI.length} : ${t(ETAPES_SUIVI[rang][1])}`}>
      {ETAPES_SUIVI.map(([code], i) => <li key={code} className={clsx('h-1.5 flex-1 rounded-full', i > rang ? 'bg-surface-bord' : statut === 'resolu' ? 'bg-succes-vif' : 'bg-marque-600')} />)}
    </ol>
  );
}

const STYLE_ALERTE = { danger: 'border-sos', vigilance: 'border-or', info: 'border-marque-600' };

export default function Accueil() {
  const { utilisateur } = useAuth();
  const config = useConfig();
  const { t, langue } = useLangue();
  const opts = { intervalle: 30000 };
  const region = utilisateur.region || undefined;
  const incidents = useRessource('/incidents/', { taille: 5 }, opts);
  const sos = useRessource('/alertes/sos/', { taille: 5 }, opts);
  const alertes = useRessource('/alertes/zones/', { region, en_cours: 1 }, { intervalle: 120000 });
  const autour = useRessource('/incidents/carte/', { region, jours: 30 });
  const notifications = useRessource('/notifications/', { taille: 4 }, opts);
  const dossiers = [...(sos.donnees?.results || []).map((d) => ({ ...d, sos: true })), ...(incidents.donnees?.results || [])]
    .sort((a, b) => new Date(b.date_creation) - new Date(a.date_creation)).slice(0, 4);
  const points = (autour.donnees?.resultats || []).map((p) => ({
    id: p.id, lat: p.latitude, lng: p.longitude, couleur: config.categorie(p.type_incident)?.couleur || COULEURS.gris,
    titre: config.categorie(p.type_incident)?.libelle,
  }));
  const zone = config.region(utilisateur.region);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-extrabold sm:text-[28px]">{t('Bonjour {nom}', { nom: utilisateur.first_name || '' })}</h1>
        <p className="text-sm text-texte-doux">{t('Que souhaitez-vous faire ?')}</p>
      </div>

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1.5fr)_minmax(320px,1fr)]">
        <div className="min-w-0 space-y-6">
          <SOS />
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            {ACTIONS.map((c) => (
              <Link key={c.a} to={c.a} className={clsx('group rounded-2xl border p-4 transition hover:-translate-y-0.5 hover:shadow-carte', c.principal ? 'border-marque-800 bg-marque-800 text-white' : 'border-surface-bord bg-surface')}>
                <c.icone className={clsx('h-6 w-6', c.principal ? 'text-white' : 'text-marque-600')} aria-hidden />
                <p className="mt-3 font-bold leading-tight">{t(c.titre)}</p>
                <p className={clsx('mt-0.5 truncate text-xs', c.principal ? 'text-white/80' : 'text-texte-doux')}>{t(c.texte)}</p>
              </Link>
            ))}
          </div>
          <Carte titre={t('Mes derniers signalements')} action={<Link to="/citoyen/dossiers" className="lien text-sm">{t('Tout voir')}</Link>} corpsClassName="p-0">
            {incidents.chargement && !incidents.donnees ? <Chargement /> : dossiers.length === 0 ? (
              <p className="p-5 text-sm text-texte-doux">{t('Aucun signalement pour l’instant.')}</p>
            ) : (
              <ul className="divide-y divide-surface-bord">
                {dossiers.map((d) => (
                  <li key={`${d.sos ? 's' : 'i'}${d.id}`}>
                    <Link to={`/citoyen/dossiers?${d.sos ? 'type=sos&' : ''}dossier=${d.id}`} className="block px-5 py-3.5 hover:bg-surface-douce">
                      <div className="flex items-center justify-between gap-3">
                        <div className="min-w-0">
                          <p className="truncate font-semibold">{d.sos ? t('Alerte SOS') : libelleCategorie(langue, d.type_incident, d.categorie_libelle)}</p>
                          <p className="truncate text-xs text-texte-doux"><span className="font-mono">{d.reference}</span> · {ilYa(d.date_creation)}</p>
                        </div>
                        <BadgeStatut statut={d.statut} />
                      </div>
                      <Progression statut={d.statut} />
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </Carte>
          <Carte titre={zone ? `${t('Autour de moi')} · ${zone.libelle}` : t('Carte des incidents')} action={<Link to="/citoyen/carte" className="lien text-sm">{t('Ouvrir la carte')}</Link>} corpsClassName="p-3">
            <CarteSenAlert points={points} hauteur={280} zoom={zone ? 10 : 6} centre={zone ? [zone.lat, zone.lng] : CENTRE_SENEGAL} />
            <p className="mt-2 px-1 text-xs text-texte-doux">{t('30 derniers jours. Positions arrondies à environ 100 m.')}</p>
          </Carte>
        </div>

        <div className="min-w-0 space-y-6">
          <Carte titre={t('Alertes de proximité')}>
            {!alertes.donnees?.results?.length ? (
              <p className="flex items-start gap-2 text-sm text-texte-doux"><ShieldCheck className="mt-0.5 h-4 w-4 shrink-0 text-succes" />{t('Aucune alerte officielle en cours pour votre région.')}</p>
            ) : (
              <ul className="space-y-3">
                {alertes.donnees.results.slice(0, 3).map((a) => (
                  <li key={a.id} className={clsx('border-l-4 pl-3', STYLE_ALERTE[a.niveau])}>
                    <p className="text-sm font-bold">{a.titre}</p>
                    <p className="text-sm text-texte-doux">{a.message}</p>
                  </li>
                ))}
              </ul>
            )}
          </Carte>
          <Carte titre={t('Notifications')} action={<Link to="/notifications" className="lien text-sm">{t('Tout voir')}</Link>} corpsClassName="p-0">
            {!notifications.donnees?.results?.length ? <p className="p-5 text-sm text-texte-doux">{t('Aucune notification.')}</p> : (
              <ul className="divide-y divide-surface-bord">
                {notifications.donnees.results.slice(0, 4).map((n) => (
                  <li key={n.id} className="flex gap-3 px-5 py-3">
                    <IconeNotification type={n.type} />
                    <div className="min-w-0">
                      <p className={clsx('truncate text-sm', !n.lue && 'font-semibold')}>{n.titre}</p>
                      <p className="truncate text-xs text-texte-doux">{n.message}</p>
                      <p className="text-xs text-texte-pale">{ilYa(n.date_creation)}</p>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </Carte>
          <Carte titre={t('Services de secours')} action={<Link to="/citoyen/services" className="lien text-sm">{t('Proches de moi')}</Link>}>
            <div className="grid gap-2">
              {config.numeros_urgence.map((n) => (
                <a key={n.numero} href={`tel:${n.numero}`} className="flex items-center justify-between rounded-xl bg-surface-douce px-3.5 py-2.5 text-sm font-semibold hover:bg-marque-50">
                  <span className="inline-flex items-center gap-2"><Phone className="h-4 w-4 text-marque-600" aria-hidden />{n.service}</span>
                  <span className="font-mono text-base font-bold">{n.numero}</span>
                </a>
              ))}
            </div>
            <Link to="/citoyen/secours" className="mt-3 flex items-center justify-between rounded-xl border border-surface-bord px-3.5 py-2.5 text-sm font-semibold hover:bg-surface-douce">
              <span className="inline-flex items-center gap-2"><BookOpenCheck className="h-4 w-4 text-marque-600" aria-hidden />{t('Premiers secours')}</span>
              <ChevronRight className="h-4 w-4 text-texte-pale" aria-hidden />
            </Link>
          </Carte>
        </div>
      </div>
    </div>
  );
}
