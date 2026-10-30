import clsx from 'clsx';
import { BellRing, ShieldAlert, Siren, Volume2, VolumeX, X } from 'lucide-react';
import { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api/client';
import { ilYa } from '../lib/format';

const INTERVALLE = 5000;
const CLE_SON = 'senalert.son-alertes';

/** Sons générés par le navigateur (aucun fichier) : sirène à deux tons pour un SOS, bip pour un incident. */
function jouer(type) {
  try {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    const ctx = jouer.ctx || (jouer.ctx = new Ctx());
    if (ctx.state === 'suspended') ctx.resume();
    const t0 = ctx.currentTime;
    const notes = type === 'sos' ? [880, 660, 880, 660, 880, 660] : [740, 990];
    const duree = type === 'sos' ? 0.32 : 0.14;
    notes.forEach((f, i) => {
      const o = ctx.createOscillator();
      const g = ctx.createGain();
      o.type = type === 'sos' ? 'sawtooth' : 'sine';
      o.frequency.value = f;
      g.gain.setValueAtTime(0.0001, t0 + i * duree);
      g.gain.exponentialRampToValueAtTime(type === 'sos' ? 0.18 : 0.12, t0 + i * duree + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + (i + 1) * duree);
      o.connect(g).connect(ctx.destination);
      o.start(t0 + i * duree);
      o.stop(t0 + (i + 1) * duree);
    });
  } catch { /* son indisponible (navigateur sans interaction préalable) */ }
}

/**
 * Alertes en direct pour la supervision et les agents : nouveaux SOS et incidents
 * visibles par l'utilisateur, détectés toutes les 5 secondes.
 */
export default function AlertesTempsReel({ role }) {
  const navigate = useNavigate();
  const [alertes, setAlertes] = useState([]);
  const [son, setSon] = useState(() => { try { return localStorage.getItem(CLE_SON) !== 'off'; } catch { return true; } });
  const [permission, setPermission] = useState(() => (typeof Notification !== 'undefined' ? Notification.permission : 'unsupported'));
  const depuis = useRef(null);
  const sonRef = useRef(son);
  sonRef.current = son;

  const chemin = useCallback((d, sos) => (role === 'superadmin'
    ? `/supervision/${sos ? 'sos' : 'incidents'}?dossier=${d.id}`
    : `/agent/interventions?${sos ? 'type=sos&' : ''}dossier=${d.id}`), [role]);

  useEffect(() => {
    let actif = true;
    const tic = async () => {
      if (document.visibilityState !== 'visible' && depuis.current) return;
      try {
        const r = await api('/tableau-de-bord/flux/', { params: { depuis: depuis.current || undefined } });
        if (!actif) return;
        const premier = !depuis.current;
        depuis.current = r.maintenant;
        if (premier) return;
        const nouvelles = [
          ...r.sos.map((d) => ({ ...d, sos: true })),
          ...r.incidents.map((d) => ({ ...d, sos: false })),
        ];
        if (!nouvelles.length) return;
        setAlertes((a) => [...nouvelles.map((d) => ({ cle: `${d.sos ? 's' : 'i'}${d.id}`, ...d })), ...a].slice(0, 5));
        if (sonRef.current) jouer(nouvelles.some((d) => d.sos) ? 'sos' : 'incident');
        if (typeof Notification !== 'undefined' && Notification.permission === 'granted' && document.visibilityState !== 'visible') {
          nouvelles.forEach((d) => new Notification(d.sos ? `Alerte SOS ${d.reference}` : `Nouveau signalement ${d.reference}`, {
            body: `${d.sos ? 'SOS' : d.categorie_libelle} — ${d.region_libelle || 'région inconnue'}`, tag: d.reference,
          }));
        }
      } catch { /* réseau : nouvel essai au prochain tic */ }
    };
    tic();
    const t = setInterval(tic, INTERVALLE);
    return () => { actif = false; clearInterval(t); };
  }, []);

  const basculerSon = () => {
    const v = !son;
    setSon(v);
    try { localStorage.setItem(CLE_SON, v ? 'on' : 'off'); } catch { /* rien */ }
    if (v) jouer('incident');
  };

  return (
    <>
      <div className="pointer-events-none fixed right-4 top-20 z-[1050] flex w-[min(92vw,380px)] flex-col gap-2" aria-live="assertive">
        {alertes.map((d) => (
          <div key={d.cle} className={clsx('pointer-events-auto animate-apparition overflow-hidden rounded-2xl shadow-flottant ring-1',
            d.sos ? 'bg-sos text-white ring-sos-fonce' : 'bg-surface text-texte ring-surface-bord')}>
            <div className="flex items-start gap-3 p-4">
              <span className={clsx('grid h-10 w-10 shrink-0 place-items-center rounded-xl', d.sos ? 'animate-pulsation bg-white/15' : 'bg-marque-50 text-marque-700')}>
                {d.sos ? <Siren className="h-5 w-5" /> : <ShieldAlert className="h-5 w-5" />}
              </span>
              <div className="min-w-0 flex-1">
                <p className="text-xs font-bold uppercase tracking-wider opacity-80">{d.sos ? 'Alerte SOS' : 'Nouveau signalement'}</p>
                <p className="font-bold">{d.reference}</p>
                <p className="truncate text-sm opacity-90">{d.sos ? 'SOS' : d.categorie_libelle} · {d.region_libelle || 'région inconnue'} · {ilYa(d.date_creation)}</p>
              </div>
              <button type="button" onClick={() => setAlertes((a) => a.filter((x) => x.cle !== d.cle))} className="rounded-lg p-1 opacity-80 hover:opacity-100" aria-label="Fermer l'alerte"><X className="h-4 w-4" /></button>
            </div>
            <button type="button" onClick={() => { setAlertes((a) => a.filter((x) => x.cle !== d.cle)); navigate(chemin(d, d.sos)); }}
              className={clsx('w-full py-2.5 text-sm font-bold', d.sos ? 'bg-black/20 hover:bg-black/30' : 'bg-surface-douce hover:bg-marque-50')}>
              Ouvrir le dossier
            </button>
          </div>
        ))}
      </div>
      <div className="fixed bottom-4 left-4 z-[1040] flex items-center gap-1 rounded-full bg-surface/95 p-1 text-xs shadow-flottant ring-1 ring-surface-bord lg:left-[calc(16rem+1rem)]">
        <span className="flex items-center gap-1.5 px-2.5 font-semibold text-texte-doux"><span className="h-2 w-2 animate-pulse rounded-full bg-succes" /> En direct</span>
        <button type="button" onClick={basculerSon} className="rounded-full p-1.5 text-texte-doux hover:bg-surface-douce" aria-label={son ? 'Couper le son des alertes' : 'Activer le son des alertes'} title={son ? 'Son activé' : 'Son coupé'}>
          {son ? <Volume2 className="h-4 w-4" /> : <VolumeX className="h-4 w-4" />}
        </button>
        {permission === 'default' && (
          <button type="button" onClick={async () => setPermission(await Notification.requestPermission())} className="rounded-full p-1.5 text-texte-doux hover:bg-surface-douce" title="Activer les notifications du navigateur" aria-label="Activer les notifications du navigateur">
            <BellRing className="h-4 w-4" />
          </button>
        )}
      </div>
    </>
  );
}
