import clsx from 'clsx';
import { Crosshair, RotateCcw, Siren, X } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, nouvelleCle } from '../api/client';
import { useRessource } from '../api/hooks';
import { BadgeStatut, Bandeau, Bouton, Chargement, Fenetre } from './ui';
import { useConfig } from '../lib/config';
import { dateHeure } from '../lib/format';
import { useLangue } from '../lib/langue';

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

/** Alerte SOS : bouton flottant, 5 s pour annuler, type d'urgence facultatif, confirmation après enregistrement. */
export default function BoutonSOS() {
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
      {/* Bouton SOS flottant : toujours visible en bas à droite de chaque page citoyen. */}
      <button type="button" onClick={demarrer} disabled={etape === 'envoi'} aria-label={t('Déclencher une alerte SOS')}
        className="fixed bottom-5 right-5 z-40 inline-flex items-center gap-2 rounded-full bg-sos-fonce px-6 py-4 font-titre text-lg font-extrabold tracking-wide text-white shadow-[0_8px_24px_rgba(185,28,28,.45)] ring-4 ring-white transition hover:bg-sos-sombre focus-visible:outline-none focus-visible:ring-sos/40 sm:bottom-7 sm:right-7">
        <Siren className="h-6 w-6" aria-hidden /> SOS
      </button>

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

