import { useMemo, useState } from 'react';
import { useRessource } from '../../api/hooks';
import CarteSenAlert, { Legende, echapper } from '../../components/Carte';
import { Bandeau, Carte, EnTetePage, EtatErreur, IndicateurSynchro, Selecteur } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { STATUTS, dateHeure } from '../../lib/format';

/** Carte des incidents récents, données minimales et positions arrondies (~100 m). */
export default function CarteIncidents() {
  const config = useConfig();
  const [jours, setJours] = useState('30');
  const [type, setType] = useState('');
  const [region, setRegion] = useState('');
  const { donnees, erreur, recharger, derniereSynchro, chargement } = useRessource('/incidents/carte/', { jours, type_incident: type, region }, { intervalle: 60000 });
  const points = useMemo(() => (donnees?.resultats || []).map((p) => {
    const c = config.categorie(p.type_incident);
    return {
      id: p.id, lat: p.latitude, lng: p.longitude, couleur: c?.couleur || '#475569', titre: c?.libelle,
      popup: `<b>${echapper(c?.libelle || p.type_incident)}</b><br/>${echapper(STATUTS[p.statut]?.libelle)} · ${echapper(dateHeure(p.date_creation))}`,
    };
  }), [donnees, config]);
  return (
    <>
      <EnTetePage titre="Carte des incidents" sousTitre="Incidents signalés récemment. Les positions sont arrondies pour protéger la vie privée."
        actions={<IndicateurSynchro date={derniereSynchro} chargement={chargement} onRafraichir={recharger} />} />
      <div className="mb-4 flex flex-wrap gap-3">
        <Selecteur aria-label="Période" className="w-auto" vide={null} valeur={jours} onChange={setJours} options={[{ code: '7', libelle: '7 derniers jours' }, { code: '30', libelle: '30 derniers jours' }, { code: '90', libelle: '90 derniers jours' }]} />
        <Selecteur aria-label="Catégorie" className="w-auto" valeur={type} onChange={setType} vide="Toutes catégories" options={config.categories} />
        <Selecteur aria-label="Région" className="w-auto" valeur={region} onChange={setRegion} vide="Toutes régions" options={config.regions} />
      </div>
      <EtatErreur erreur={erreur} onReessayer={recharger} />
      {donnees?.desactivee && <Bandeau type="info">La carte publique est désactivée par l’administrateur.</Bandeau>}
      <Carte corpsClassName="space-y-3 p-3">
        <CarteSenAlert points={points} hauteur={560} cadrer={points.length > 0} />
        <div className="flex flex-wrap items-center justify-between gap-2 px-1">
          <Legende elements={config.categories.map((c) => ({ libelle: c.libelle, couleur: c.couleur }))} />
          <p className="text-xs text-texte-pale">{points.length} incident(s) · {donnees?.note}</p>
        </div>
      </Carte>
      <p className="mt-3 text-xs text-texte-pale">L’absence d’incident sur la carte ne signifie pas qu’une zone est sans danger.</p>
    </>
  );
}
