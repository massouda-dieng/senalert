import { Camera, Info } from 'lucide-react';
import { useMemo, useState } from 'react';
import { Circle, Tooltip as InfoCarte } from 'react-leaflet';
import { api } from '../../api/client';
import { useRessource } from '../../api/hooks';
import CarteSenAlert, { Legende } from '../../components/Carte';
import { Bandeau, Bouton, Carte, Chargement, EnTetePage, EtatErreur, Selecteur, useToast } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { NIVEAUX_RISQUE, dateHeure, isoJour } from '../../lib/format';

/** Score de risque par région — méthode de référence du mémoire, calculée par le backend. */
export default function Risques() {
  const config = useConfig();
  const toast = useToast();
  const [periode, setPeriode] = useState('');
  const [categorie, setCategorie] = useState('');
  const [comparer, setComparer] = useState(false);
  const params = periode
    ? { date_debut: isoJour(Date.now() - (Number(periode) - 1) * 86400000), date_fin: isoJour(Date.now()), comparer: comparer ? 1 : undefined, type_incident: categorie }
    : { type_incident: categorie };
  const { donnees, chargement, erreur, recharger } = useRessource('/analyse/zones-risque/', params);
  const zones = donnees?.zones || [];
  const max = useMemo(() => Math.max(1, ...zones.map((z) => z.score)), [zones]);

  const instantane = async () => {
    try { await api('/analyse/zones-risque/historique/', { methode: 'POST' }); toast('Instantané des scores enregistré.'); recharger(true); } catch (e) { toast(e.detail, 'erreur'); }
  };

  return (
    <>
      <EnTetePage titre="Carte & zones de risque" sousTitre="Score par région calculé à partir de l’historique des signalements (méthode de référence du mémoire)."
        actions={<Bouton variante="secondaire" icone={Camera} onClick={instantane}>Enregistrer un instantané</Bouton>} />
      <div className="carte mb-5 flex flex-wrap items-center gap-3 p-3">
        <Selecteur aria-label="Période" className="w-auto" valeur={periode} onChange={(v) => { setPeriode(v); if (!v) setComparer(false); }} vide="Tout l’historique"
          options={[{ code: '7', libelle: '7 derniers jours' }, { code: '30', libelle: '30 derniers jours' }, { code: '90', libelle: '90 derniers jours' }]} />
        <Selecteur aria-label="Catégorie" className="w-auto" valeur={categorie} onChange={setCategorie} vide="Toutes catégories" options={config.categories} />
        <label className="inline-flex items-center gap-2 text-sm"><input type="checkbox" disabled={!periode} checked={comparer} onChange={(e) => setComparer(e.target.checked)} /> Comparer à la période précédente</label>
        {donnees && <span className="ml-auto text-xs text-texte-pale">{donnees.nb_incidents_utilises} incident(s) utilisés · calcul du {dateHeure(donnees.date_calcul)}{donnees.dernier_instantane ? ` · dernier instantané ${dateHeure(donnees.dernier_instantane)}` : ''}</span>}
      </div>
      <Bandeau type="info" className="mb-5">{donnees?.avertissement || 'Indicateur descriptif, pas un modèle prédictif.'}</Bandeau>
      <EtatErreur erreur={erreur} onReessayer={recharger} />
      {chargement && !donnees ? <Chargement /> : (
        <div className="grid gap-5 xl:grid-cols-[1fr_520px]">
          <Carte corpsClassName="space-y-3 p-3">
            <CarteSenAlert hauteur={560}>
              {zones.filter((z) => z.total_incidents > 0).map((z) => (
                <Circle key={z.region} center={[z.latitude, z.longitude]} radius={9000 + 26000 * (z.score / max)}
                  pathOptions={{ color: NIVEAUX_RISQUE[z.niveau].couleur, fillColor: NIVEAUX_RISQUE[z.niveau].couleur, fillOpacity: 0.28, weight: 2, dashArray: z.donnees_insuffisantes ? '6 6' : undefined }}>
                  <InfoCarte>{z.region_libelle} : {z.score} ({NIVEAUX_RISQUE[z.niveau].libelle}){z.donnees_insuffisantes ? ' — données insuffisantes' : ''}</InfoCarte>
                </Circle>
              ))}
            </CarteSenAlert>
            <Legende elements={Object.values(NIVEAUX_RISQUE)} />
            <p className="text-xs text-texte-pale">Cercles centrés sur les chefs-lieux de région ; contour pointillé = moins de {donnees?.formule.min_incidents_fiable} incidents (niveau peu fiable).</p>
          </Carte>
          <Carte titre="Classement des régions" corpsClassName="max-h-[640px] overflow-y-auto p-0">
            <table className="w-full text-sm">
              <thead className="sticky top-0 bg-surface-douce text-left text-xs uppercase text-texte-doux">
                <tr><th className="px-4 py-2">Région</th><th className="px-4 py-2 text-right">Score</th><th className="px-4 py-2">Niveau</th><th className="px-4 py-2 text-right">Inc. (7 j)</th>{comparer && <th className="px-4 py-2 text-right">Évol.</th>}</tr>
              </thead>
              <tbody className="divide-y divide-surface-bord">
                {zones.map((z) => (
                  <tr key={z.region} className={z.donnees_insuffisantes ? 'text-texte-doux' : ''}>
                    <td className="px-4 py-2">
                      <p className="font-medium">{z.region_libelle}</p>
                      {z.types_predominants.length > 0 && <p className="text-xs text-texte-pale">{z.types_predominants.map((t) => config.categorie(t)?.libelle || t).join(', ')}</p>}
                    </td>
                    <td className="px-4 py-2 text-right font-semibold tabular-nums">{z.score}</td>
                    <td className="px-4 py-2"><span className="inline-flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-full" style={{ background: NIVEAUX_RISQUE[z.niveau].couleur }} />{NIVEAUX_RISQUE[z.niveau].libelle}</span>{z.donnees_insuffisantes && <p className="text-[11px]">données insuffisantes</p>}</td>
                    <td className="px-4 py-2 text-right tabular-nums">{z.total_incidents} ({z.incidents_recents})</td>
                    {comparer && <td className={`px-4 py-2 text-right tabular-nums ${z.evolution > 0 ? 'text-red-700' : z.evolution < 0 ? 'text-emerald-700' : ''}`}>{z.evolution > 0 ? '+' : ''}{z.evolution}</td>}
                  </tr>
                ))}
              </tbody>
            </table>
          </Carte>
        </div>
      )}
      {donnees && (
        <details className="carte mt-5 p-5 text-sm">
          <summary className="flex cursor-pointer items-center gap-2 font-semibold"><Info className="h-4 w-4" /> Formule de calcul ({donnees.methode})</summary>
          <p className="mt-3 font-mono text-[13px]">score_région = Σ poids(catégorie) × facteur_temporel</p>
          <ul className="mt-2 list-disc space-y-1 pl-5 text-texte-doux">
            <li>Poids : {Object.entries(donnees.formule.poids).map(([k, v]) => `${config.categorie(k)?.libelle || k} ${v}`).join(' · ')} · autres catégories {donnees.formule.poids_par_defaut}</li>
            <li>Facteur temporel : ×{donnees.formule.facteur_recent} si l’incident a moins de {donnees.formule.fenetre_recente_jours} jours (par rapport à la fin de période), sinon ×1</li>
            <li>Seuils : critique ≥ {donnees.formule.seuils.critique} · élevé ≥ {donnees.formule.seuils.eleve} · moyen ≥ {donnees.formule.seuils.moyen} · faible en dessous</li>
            <li>{donnees.formule.exclusions}</li>
          </ul>
        </details>
      )}
    </>
  );
}
