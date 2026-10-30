import clsx from 'clsx';
import { Clock, FileDown, FileSpreadsheet, Filter, Inbox, RotateCcw, Siren, SlidersHorizontal } from 'lucide-react';
import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { telecharger } from '../api/client';
import { useRessource } from '../api/hooks';
import { useConfig } from '../lib/config';
import { GRAVITES, STATUTS, dateHeure, ilYa } from '../lib/format';
import DossierDetail from './DossierDetail';
import {
  BadgeGravite, BadgeStatut, Bouton, Chargement, EtatErreur, EtatVide, IndicateurSynchro, Onglets, Pagination, Selecteur, useToast,
} from './ui';

const FILTRES = ['q', 'statut', 'region', 'type_incident', 'gravite', 'date_debut', 'date_fin', 'affecte_a_moi', 'actifs', 'doublons'];

/**
 * type : 'incident' | 'sos'
 * filtresVisibles : sous-ensemble de FILTRES à afficher (tout sauf la recherche est replié derrière « Filtres »)
 * vues : raccourcis [{ code, libelle, filtres }], le premier étant la vue par défaut
 * exports : affiche les boutons CSV / PDF (superadmin)
 */
export default function ListeDossiers({ type = 'incident', filtresVisibles = FILTRES, exports = false, vues, intervalle = 30000, vide }) {
  const config = useConfig();
  const toast = useToast();
  const [params, setParams] = useSearchParams();
  const [selection, setSelection] = useState(params.get('dossier'));
  const [exportEnCours, setExportEnCours] = useState(null);
  const [filtresOuverts, setFiltresOuverts] = useState(() => filtresVisibles.some((f) => f !== 'q' && params.get(f)));
  const page = Number(params.get('page') || 1);

  const vue = vues?.find((v) => v.code === params.get('vue')) || vues?.[0];
  const filtres = Object.fromEntries(FILTRES.map((f) => [f, params.get(f) ?? '']));
  const requete = { ...filtres, ...vue?.filtres, page, ordering: params.get('ordering') || '-date_creation' };
  const { donnees, chargement, erreur, recharger, derniereSynchro } = useRessource(type === 'sos' ? '/alertes/sos/' : '/incidents/', requete, { intervalle });

  const changer = (cle, valeur) => {
    const p = new URLSearchParams(params);
    if (valeur === '' || valeur == null || valeur === false) p.delete(cle); else p.set(cle, valeur);
    if (cle !== 'page') p.delete('page');
    setParams(p, { replace: true });
  };
  const ouvrir = (id) => {
    setSelection(String(id));
    const p = new URLSearchParams(params);
    p.set('dossier', id);
    setParams(p, { replace: true });
  };
  const changerVue = (code) => {
    const p = new URLSearchParams(params);
    if (code === vues[0].code) p.delete('vue'); else p.set('vue', code);
    p.delete('page');
    setParams(p, { replace: true });
  };
  const reinitialiser = () => {
    const p = new URLSearchParams(params);
    [...FILTRES, 'page'].forEach((f) => p.delete(f));
    setParams(p, { replace: true });
  };
  const fermer = () => {
    setSelection(null);
    const p = new URLSearchParams(params);
    p.delete('dossier');
    setParams(p, { replace: true });
  };
  const exporter = async (format) => {
    setExportEnCours(format);
    try {
      const { q, statut, region, type_incident: t, gravite, date_debut: dd, date_fin: df } = filtres;
      await telecharger(`/tableau-de-bord/export/${format}/`, { q, statut, region, type_incident: t, gravite, date_debut: dd, date_fin: df }, `senalert.${format}`);
      toast(`Export ${format.toUpperCase()} téléchargé.`);
    } catch (e) { toast(e.detail, 'erreur'); } finally { setExportEnCours(null); }
  };
  const nbFiltres = FILTRES.filter((f) => params.get(f)).length;
  const nbDansPanneau = nbFiltres - (params.get('q') ? 1 : 0);
  const lignes = donnees?.results || [];

  return (
    <div className={clsx('grid gap-5', selection && 'xl:grid-cols-[minmax(0,1fr)_minmax(400px,460px)]')}>
      <div className="min-w-0 space-y-4">
        <div className="carte p-3">
          <div className="flex flex-wrap items-center gap-3">
            {vues && <Onglets actif={vue.code} onChange={changerVue} onglets={vues} />}
            {filtresVisibles.includes('q') && (
              <input key={filtres.q} className="champ w-full min-w-0 flex-1 py-2 sm:w-auto sm:min-w-[200px]" placeholder="Référence, adresse, texte…" defaultValue={filtres.q} aria-label="Recherche"
                onKeyDown={(e) => { if (e.key === 'Enter') changer('q', e.currentTarget.value.trim()); }} onBlur={(e) => changer('q', e.currentTarget.value.trim())} />
            )}
            <div className="ml-auto flex items-center gap-2">
              {nbFiltres > 0 && <Bouton variante="fantome" taille="sm" icone={RotateCcw} onClick={reinitialiser}>Réinitialiser</Bouton>}
              {filtresVisibles.some((f) => f !== 'q') && <Bouton variante="secondaire" taille="sm" icone={SlidersHorizontal} aria-expanded={filtresOuverts} onClick={() => setFiltresOuverts((o) => !o)}>Filtres{nbDansPanneau > 0 && ` (${nbDansPanneau})`}</Bouton>}
              {exports && <>
                <Bouton variante="secondaire" taille="sm" icone={FileSpreadsheet} chargement={exportEnCours === 'csv'} onClick={() => exporter('csv')}>CSV</Bouton>
                <Bouton variante="secondaire" taille="sm" icone={FileDown} chargement={exportEnCours === 'pdf'} onClick={() => exporter('pdf')}>Rapport PDF</Bouton>
              </>}
            </div>
          </div>
          {filtresOuverts && (
            <div className="mt-3 flex flex-wrap items-end gap-3 border-t border-surface-bord pt-3">
              {filtresVisibles.includes('statut') && <Selecteur aria-label="Statut" className="w-auto" valeur={filtres.statut} onChange={(v) => changer('statut', v)} vide="Tous statuts"
                options={Object.entries(STATUTS).map(([code, s]) => ({ code, libelle: s.libelle }))} />}
              {filtresVisibles.includes('type_incident') && type === 'incident' && <Selecteur aria-label="Catégorie" className="w-auto" valeur={filtres.type_incident} onChange={(v) => changer('type_incident', v)} vide="Toutes catégories"
                options={config.categories.map((c) => ({ code: c.code, libelle: c.libelle }))} />}
              {filtresVisibles.includes('region') && <Selecteur aria-label="Région" className="w-auto" valeur={filtres.region} onChange={(v) => changer('region', v)} vide="Toutes régions"
                options={config.regions.map((r) => ({ code: r.code, libelle: r.libelle }))} />}
              {filtresVisibles.includes('gravite') && <Selecteur aria-label="Gravité" className="w-auto" valeur={filtres.gravite} onChange={(v) => changer('gravite', v)} vide="Toutes gravités"
                options={Object.entries(GRAVITES).map(([code, g]) => ({ code, libelle: g.libelle }))} />}
              {filtresVisibles.includes('date_debut') && <label className="text-xs text-texte-doux">Du<input type="date" className="champ mt-1 py-2" value={filtres.date_debut} onChange={(e) => changer('date_debut', e.target.value)} /></label>}
              {filtresVisibles.includes('date_fin') && <label className="text-xs text-texte-doux">Au<input type="date" className="champ mt-1 py-2" value={filtres.date_fin} onChange={(e) => changer('date_fin', e.target.value)} /></label>}
              {filtresVisibles.includes('affecte_a_moi') && (
                <label className="inline-flex items-center gap-2 pb-2 text-sm"><input type="checkbox" checked={filtres.affecte_a_moi === 'true'} onChange={(e) => changer('affecte_a_moi', e.target.checked ? 'true' : '')} /> Mes interventions</label>
              )}
              {filtresVisibles.includes('actifs') && (
                <label className="inline-flex items-center gap-2 pb-2 text-sm"><input type="checkbox" checked={filtres.actifs === 'true'} onChange={(e) => changer('actifs', e.target.checked ? 'true' : '')} /> Dossiers ouverts</label>
              )}
              {filtresVisibles.includes('doublons') && type === 'incident' && (
                <label className="inline-flex items-center gap-2 pb-2 text-sm"><input type="checkbox" checked={filtres.doublons === 'true'} onChange={(e) => changer('doublons', e.target.checked ? 'true' : '')} /> Doublons potentiels</label>
              )}
            </div>
          )}
        </div>

        <EtatErreur erreur={erreur} onReessayer={recharger} />

        <div className="carte overflow-hidden">
          <div className="flex items-center justify-between border-b border-surface-bord px-4 py-2.5">
            <p className="inline-flex items-center gap-2 text-sm font-semibold"><Filter className="h-4 w-4 text-texte-pale" /> {donnees ? `${donnees.count} dossier${donnees.count > 1 ? 's' : ''}` : '…'}</p>
            <IndicateurSynchro date={derniereSynchro} chargement={chargement} onRafraichir={() => recharger()} />
          </div>
          {chargement && !donnees ? <Chargement /> : lignes.length === 0 ? (
            <EtatVide icone={type === 'sos' ? Siren : Inbox} titre={vide?.titre || 'Aucun dossier'} texte={nbFiltres ? 'Aucun résultat pour ces filtres.' : vide?.texte} action={vide?.action} />
          ) : (
            <>
              <div className="hidden overflow-x-auto md:block">
              <table className="w-full min-w-[600px] text-sm">
                <thead className="bg-surface-douce text-left text-xs uppercase tracking-wide text-texte-doux">
                  <tr>
                    <th className="px-4 py-2.5 font-semibold">Dossier</th>
                    <th className="px-4 py-2.5 font-semibold">Région</th>
                    <th className="px-4 py-2.5 font-semibold">Statut</th>
                    <th className="px-4 py-2.5 font-semibold">Gravité</th>
                    <th className="px-4 py-2.5 font-semibold">
                      <button type="button" className="uppercase" onClick={() => changer('ordering', params.get('ordering') === 'date_creation' ? '-date_creation' : 'date_creation')}>
                        Créé {params.get('ordering') === 'date_creation' ? '↑' : '↓'}
                      </button>
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-surface-bord">
                  {lignes.map((d) => (
                    <tr key={d.id} onClick={() => ouvrir(d.id)} onKeyDown={(e) => e.key === 'Enter' && ouvrir(d.id)} tabIndex={0}
                      className={clsx('cursor-pointer transition hover:bg-marque-50/60 focus:bg-marque-50', String(d.id) === selection && 'bg-marque-50')}>
                      <td className="px-4 py-3">
                        <p className="font-semibold">{type === 'sos' ? 'Alerte SOS' : d.categorie_libelle}</p>
                        <p className="whitespace-nowrap font-mono text-xs text-marque-700">{d.reference}</p>
                      </td>
                      <td className="px-4 py-3 text-texte-doux">
                        {d.region_libelle || '—'}
                        {d.latitude == null && <p className="whitespace-nowrap text-xs text-amber-700">GPS indisponible</p>}
                      </td>
                      <td className="px-4 py-3"><BadgeStatut statut={d.statut} /></td>
                      <td className="px-4 py-3"><BadgeGravite gravite={d.gravite} /></td>
                      <td className="whitespace-nowrap px-4 py-3 text-texte-doux" title={dateHeure(d.date_creation)}>
                        {ilYa(d.date_creation)}
                        {d.en_retard && <p className="flex items-center gap-1 text-xs font-semibold text-amber-700"><Clock className="h-3 w-3" aria-hidden /> En retard</p>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              </div>
              <ul className="divide-y divide-surface-bord md:hidden">
                {lignes.map((d) => (
                  <li key={d.id}>
                    <button type="button" onClick={() => ouvrir(d.id)} className="w-full px-4 py-3 text-left">
                      <div className="flex items-center justify-between gap-2">
                        <span className="font-mono text-[13px] font-semibold text-marque-700">{d.reference}</span>
                        <BadgeStatut statut={d.statut} />
                      </div>
                      <p className="mt-1 text-sm font-medium">{type === 'sos' ? 'Alerte SOS' : d.categorie_libelle} · {d.region_libelle || '—'}</p>
                      <p className="text-xs text-texte-pale">{ilYa(d.date_creation)}{d.en_retard && <span className="font-semibold text-amber-700"> · En retard</span>}</p>
                    </button>
                  </li>
                ))}
              </ul>
            </>
          )}
          {donnees && <div className="border-t border-surface-bord px-3"><Pagination page={page} total={donnees.count} onPage={(p) => changer('page', p)} /></div>}
        </div>
      </div>

      {selection && (
        <aside className="fixed inset-0 z-[950] overflow-y-auto bg-surface p-5 xl:sticky xl:inset-auto xl:top-20 xl:z-auto xl:max-h-[calc(100vh-6rem)] xl:rounded-2xl xl:border xl:border-surface-bord xl:shadow-carte" aria-label="Détail du dossier">
          <DossierDetail key={selection} type={type} id={selection} onFermer={fermer} onModifie={() => recharger(true)} compact />
        </aside>
      )}
    </div>
  );
}
