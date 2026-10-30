import clsx from 'clsx';
import { CheckCircle2, Pause, Play, Presentation, RotateCcw, SkipForward } from 'lucide-react';
import { useEffect, useMemo, useRef, useState } from 'react';
import { api } from '../../api/client';
import { useRessource } from '../../api/hooks';
import CarteSenAlert from '../../components/Carte';
import { Chronologie } from '../../components/DossierDetail';
import Photo from '../../components/Photo';
import { BadgeStatut, Bandeau, Bouton, Carte, Chargement, EtatErreur } from '../../components/ui';

const DELAI_AUTO = 7000;

/** Démonstration guidée pour la soutenance : parcours complet joué avec les comptes de test. */
export default function Demonstration() {
  const { donnees: def, erreur: erreurDef } = useRessource('/tableau-de-bord/demo/');
  const [faite, setFaite] = useState(0);
  const [ids, setIds] = useState({});
  const [dossiers, setDossiers] = useState({ sos: null, incident: null });
  const [evenements, setEvenements] = useState([]);
  const [erreur, setErreur] = useState(null);
  const [envoi, setEnvoi] = useState(false);
  const [auto, setAuto] = useState(false);
  const etapes = def?.etapes || [];
  const fini = faite >= etapes.length && etapes.length > 0;
  const minuteur = useRef(null);

  const suivante = async () => {
    if (envoi || fini) return;
    setEnvoi(true);
    setErreur(null);
    try {
      const r = await api('/tableau-de-bord/demo/', { methode: 'POST', corps: { etape: faite + 1, ...ids } });
      const n = { ...ids, ...(r.sos ? { sos: r.sos.id } : {}), ...(r.incident ? { incident: r.incident.id } : {}) };
      setIds(n);
      setDossiers((d) => ({ sos: r.sos || d.sos, incident: r.incident || d.incident }));
      setFaite(r.etape);
      if (n.incident) setEvenements(await api(`/incidents/${n.incident}/evenements/`));
    } catch (e) { setErreur(e); setAuto(false); } finally { setEnvoi(false); }
  };

  useEffect(() => {
    if (!auto || fini) { if (fini) setAuto(false); return undefined; }
    minuteur.current = setTimeout(suivante, faite === 0 ? 300 : DELAI_AUTO);
    return () => clearTimeout(minuteur.current);
  }, [auto, faite, fini]); // eslint-disable-line react-hooks/exhaustive-deps

  const recommencer = () => { setFaite(0); setIds({}); setDossiers({ sos: null, incident: null }); setEvenements([]); setErreur(null); setAuto(false); };

  const points = useMemo(() => [
    dossiers.sos && { id: 's', lat: dossiers.sos.latitude, lng: dossiers.sos.longitude, couleur: '#E31B23', sos: true, taille: 22 },
    dossiers.incident && { id: 'i', lat: dossiers.incident.latitude, lng: dossiers.incident.longitude, couleur: '#DC2626', taille: 18 },
  ].filter(Boolean), [dossiers]);

  if (erreurDef) return <EtatErreur erreur={erreurDef} />;
  if (!def) return <Chargement />;

  return (
    <>
      <div className="relative mb-6 overflow-hidden rounded-3xl text-white">
        <Photo nom="ambulance-pompiers" className="absolute inset-0 h-full w-full" alt="" credit={false} />
        <div className="absolute inset-0 bg-gradient-to-r from-black/85 via-black/60 to-black/10" aria-hidden />
        <div className="relative flex flex-wrap items-end justify-between gap-4 px-6 py-8 sm:px-8">
          <div>
            <p className="flex items-center gap-2 text-sm font-semibold uppercase tracking-widest text-or"><Presentation className="h-4 w-4" /> Soutenance</p>
            <h1 className="font-titre text-3xl font-extrabold">Démonstration guidée</h1>
            <p className="mt-1 max-w-xl text-white/80">Un parcours complet, du SOS à la résolution, joué en direct avec les comptes de test. Les alertes en temps réel s’affichent comme en conditions réelles.</p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Bouton variante="secondaire" icone={RotateCcw} onClick={recommencer}>Recommencer</Bouton>
            <Bouton variante="secondaire" icone={auto ? Pause : Play} disabled={fini} onClick={() => setAuto((a) => !a)}>{auto ? 'Pause' : 'Lecture automatique'}</Bouton>
            <Bouton icone={SkipForward} chargement={envoi} disabled={fini} onClick={suivante}>{faite === 0 ? 'Démarrer' : 'Étape suivante'}</Bouton>
          </div>
        </div>
      </div>

      {!def.active && <Bandeau type="alerte" className="mb-4">La démonstration guidée est désactivée sur ce serveur (DEMO_GUIDEE=False).</Bandeau>}
      <EtatErreur erreur={erreur} onReessayer={erreur?.status === 409 ? recommencer : undefined} />

      <div className="grid gap-5 xl:grid-cols-[380px_1fr]">
        <Carte titre="Déroulé" corpsClassName="p-3">
          <ol className="space-y-1">
            {etapes.map((e) => {
              const etat = e.numero <= faite ? 'fait' : e.numero === faite + 1 ? 'courant' : 'avenir';
              return (
                <li key={e.numero} className={clsx('rounded-2xl p-3 transition', etat === 'courant' && 'bg-marque-50 ring-1 ring-marque-600/30', etat === 'avenir' && 'opacity-55')}>
                  <p className="flex items-center gap-2 font-semibold">
                    {etat === 'fait' ? <CheckCircle2 className="h-5 w-5 text-succes" /> : <span className={clsx('grid h-5 w-5 place-items-center rounded-full text-[11px] font-bold', etat === 'courant' ? 'bg-marque-600 text-white' : 'bg-surface-douce text-texte-doux')}>{e.numero}</span>}
                    {e.titre}
                  </p>
                  {etat !== 'avenir' && <p className="mt-1 pl-7 text-sm text-texte-doux">{e.narration}</p>}
                </li>
              );
            })}
          </ol>
          {fini && <Bandeau type="succes" className="mt-3" titre="Démonstration terminée">Les indicateurs de la supervision intègrent ce parcours. Nettoyage : <code>python manage.py donnees_demo --supprimer</code>.</Bandeau>}
        </Carte>

        <div className="space-y-5">
          <div className="grid gap-4 md:grid-cols-2">
            {[['Alerte SOS', dossiers.sos], ['Signalement', dossiers.incident]].map(([t, d]) => (
              <Carte key={t} corpsClassName="p-4">
                <p className="text-xs font-bold uppercase tracking-wide text-texte-pale">{t}</p>
                {d ? (
                  <div className="mt-1 flex items-center justify-between gap-2">
                    <div><p className="font-mono font-bold text-marque-700">{d.reference}</p><p className="text-sm text-texte-doux">{d.categorie_libelle || 'SOS'} · {d.region_libelle}{d.intervention?.agent_nom ? ` · ${d.intervention.agent_nom}` : ''}</p></div>
                    <BadgeStatut statut={d.statut} />
                  </div>
                ) : <p className="mt-1 text-sm text-texte-pale">En attente…</p>}
              </Carte>
            ))}
          </div>
          <div className="grid gap-5 lg:grid-cols-2">
            <CarteSenAlert points={points} hauteur={380} zoom={14} centre={[14.6735, -17.4374]} regrouper={false} />
            <Carte titre="Historique du signalement" corpsClassName="max-h-[380px] overflow-y-auto p-5">
              {evenements.length ? <Chronologie evenements={evenements} /> : <p className="text-sm text-texte-pale">L’historique horodaté apparaîtra ici.</p>}
            </Carte>
          </div>
        </div>
      </div>
    </>
  );
}
