import { Megaphone, Plus, StopCircle } from 'lucide-react';
import { useState } from 'react';
import { api } from '../../api/client';
import { useRessource } from '../../api/hooks';
import { Bandeau, Bouton, Champ, Chargement, EnTetePage, EtatErreur, EtatVide, Fenetre, Pagination, Selecteur, useToast } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { dateHeure } from '../../lib/format';

const NIVEAUX = [{ code: 'info', libelle: 'Information' }, { code: 'vigilance', libelle: 'Vigilance' }, { code: 'danger', libelle: 'Danger' }];
const STYLE = { danger: 'bg-sos text-white', vigilance: 'bg-or text-texte', info: 'bg-marque-700 text-white' };

function Formulaire({ onFermer, onFait }) {
  const config = useConfig();
  const [f, setF] = useState({ titre: '', message: '', consignes: '', niveau: 'vigilance', categorie: '', regions: [], date_fin: '' });
  const [erreur, setErreur] = useState(null);
  const [envoi, setEnvoi] = useState(false);
  const maj = (k) => (v) => setF((x) => ({ ...x, [k]: v?.target ? v.target.value : v }));
  return (
    <Fenetre ouverte large onFermer={onFermer} titre="Publier une alerte de zone" pied={<>
      <Bouton variante="secondaire" onClick={onFermer}>Annuler</Bouton>
      <Bouton icone={Megaphone} chargement={envoi} disabled={f.titre.length < 3 || f.message.length < 5} onClick={async () => {
        setEnvoi(true); setErreur(null);
        try {
          await api('/alertes/zones/', { methode: 'POST', corps: { ...f, date_fin: f.date_fin ? new Date(f.date_fin).toISOString() : null } });
          onFait(); onFermer();
        } catch (e) { setErreur(e.detail); } finally { setEnvoi(false); }
      }}>Publier et notifier</Bouton>
    </>}>
      <div className="space-y-4">
        <Bandeau type="alerte">Les citoyens et agents des régions choisies recevront une notification. Publiez uniquement une information vérifiée.</Bandeau>
        <div className="grid gap-4 sm:grid-cols-[1fr_180px]">
          <Champ libelle="Titre" requis>{(id) => <input id={id} className="champ" maxLength={120} value={f.titre} onChange={maj('titre')} placeholder="Ex. : Fortes pluies attendues cette nuit" />}</Champ>
          <Champ libelle="Niveau">{(id) => <Selecteur id={id} vide={null} valeur={f.niveau} onChange={maj('niveau')} options={NIVEAUX} />}</Champ>
        </div>
        <Champ libelle="Message" requis>{(id) => <textarea id={id} rows={3} className="champ" maxLength={1000} value={f.message} onChange={maj('message')} />}</Champ>
        <Champ libelle="Consignes (facultatif)">{(id) => <textarea id={id} rows={2} className="champ" maxLength={1000} value={f.consignes} onChange={maj('consignes')} placeholder="Ex. : évitez les zones basses, coupez l’électricité…" />}</Champ>
        <div className="grid gap-4 sm:grid-cols-2">
          <Champ libelle="Catégorie concernée">{(id) => <Selecteur id={id} valeur={f.categorie} onChange={maj('categorie')} vide="Aucune" options={config.categories} />}</Champ>
          <Champ libelle="Fin (facultatif)">{(id) => <input id={id} type="datetime-local" className="champ" value={f.date_fin} onChange={maj('date_fin')} />}</Champ>
        </div>
        <div>
          <p className="etiquette">Régions (aucune = tout le Sénégal)</p>
          <div className="grid grid-cols-2 gap-1.5 sm:grid-cols-4">
            {config.regions.map((r) => (
              <label key={r.code} className="inline-flex items-center gap-2 text-sm">
                <input type="checkbox" checked={f.regions.includes(r.code)} onChange={(e) => setF((x) => ({ ...x, regions: e.target.checked ? [...x.regions, r.code] : x.regions.filter((c) => c !== r.code) }))} />{r.libelle}
              </label>
            ))}
          </div>
        </div>
        {erreur && <Bandeau type="danger">{erreur}</Bandeau>}
      </div>
    </Fenetre>
  );
}

export default function AlertesZone() {
  const toast = useToast();
  const [page, setPage] = useState(1);
  const [creation, setCreation] = useState(false);
  const { donnees, chargement, erreur, recharger } = useRessource('/alertes/zones/', { page });
  return (
    <>
      <EnTetePage titre="Alertes de zone" sousTitre="Informez les habitants d’une ou plusieurs régions : intempéries, coupures, consignes de sécurité."
        actions={<Bouton icone={Plus} onClick={() => setCreation(true)}>Nouvelle alerte</Bouton>} />
      <EtatErreur erreur={erreur} onReessayer={recharger} />
      {chargement && !donnees ? <Chargement /> : !donnees?.results.length ? (
        <EtatVide icone={Megaphone} titre="Aucune alerte publiée" texte="Les alertes apparaissent en bandeau chez les citoyens concernés et sur la carte." />
      ) : (
        <div className="space-y-3">
          {donnees.results.map((a) => (
            <article key={a.id} className="carte flex flex-wrap items-start gap-4 p-5">
              <span className={`rounded-xl px-3 py-1 text-xs font-bold uppercase ${STYLE[a.niveau]}`}>{NIVEAUX.find((n) => n.code === a.niveau)?.libelle}</span>
              <div className="min-w-0 flex-1">
                <h2 className="font-bold">{a.titre} {a.en_cours ? <span className="ml-2 rounded-full bg-succes-clair px-2 py-0.5 text-xs text-succes">en cours</span> : <span className="ml-2 rounded-full bg-slate-100 px-2 py-0.5 text-xs text-slate-600">terminée</span>}</h2>
                <p className="mt-1 text-sm">{a.message}</p>
                {a.consignes && <p className="mt-1 text-sm text-texte-doux"><b>Consignes :</b> {a.consignes}</p>}
                <p className="mt-2 text-xs text-texte-pale">{a.regions_libelles.join(', ')} · du {dateHeure(a.date_debut)}{a.date_fin ? ` au ${dateHeure(a.date_fin)}` : ''}</p>
              </div>
              {a.en_cours && <Bouton variante="secondaire" taille="sm" icone={StopCircle} onClick={async () => { await api(`/alertes/zones/${a.id}/terminer/`, { methode: 'POST' }); toast('Alerte terminée.'); recharger(true); }}>Terminer</Bouton>}
            </article>
          ))}
          <Pagination page={page} total={donnees.count} onPage={setPage} />
        </div>
      )}
      {creation && <Formulaire onFermer={() => setCreation(false)} onFait={() => { toast('Alerte publiée : les habitants concernés sont notifiés.'); recharger(true); }} />}
    </>
  );
}
