import { Pencil, Plus, Save } from 'lucide-react';
import { useEffect, useState } from 'react';
import { api } from '../../api/client';
import { useRessource } from '../../api/hooks';
import { Bandeau, Bouton, Carte, Champ, Chargement, EnTetePage, EtatErreur, Fenetre, Pagination, Selecteur, useToast } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { GRAVITES, dateHeure } from '../../lib/format';

/* ---------------------------------------------------------- Services & catégories */

function Editeur({ titre, champs, initial, chemin, onFermer, onFait }) {
  const [f, setF] = useState(initial);
  const [erreur, setErreur] = useState(null);
  const [envoi, setEnvoi] = useState(false);
  return (
    <Fenetre ouverte onFermer={onFermer} titre={titre} pied={<>
      <Bouton variante="secondaire" onClick={onFermer}>Annuler</Bouton>
      <Bouton icone={Save} chargement={envoi} onClick={async () => {
        setEnvoi(true); setErreur(null);
        try { await api(initial.id ? `${chemin}${initial.id}/` : chemin, { methode: initial.id ? 'PATCH' : 'POST', corps: f }); onFait(); onFermer(); } catch (e) { setErreur(e.detail); } finally { setEnvoi(false); }
      }}>Enregistrer</Bouton>
    </>}>
      <div className="space-y-4">
        {champs.map((c) => (
          <Champ key={c.cle} libelle={c.libelle} aide={c.aide}>{(id) => (
            c.options ? <Selecteur id={id} vide={c.vide ?? null} valeur={f[c.cle] == null ? '' : String(f[c.cle])} onChange={(v) => setF((x) => ({ ...x, [c.cle]: c.nombre ? (v ? Number(v) : null) : v }))} options={c.options} />
              : c.type === 'bool' ? <label className="inline-flex items-center gap-2 text-sm"><input id={id} type="checkbox" checked={Boolean(f[c.cle])} onChange={(e) => setF((x) => ({ ...x, [c.cle]: e.target.checked }))} /> Actif</label>
                : <input id={id} type={c.type || 'text'} className="champ" disabled={c.lectureSeule && initial.id} value={f[c.cle] ?? ''} onChange={(e) => setF((x) => ({ ...x, [c.cle]: c.type === 'number' ? Number(e.target.value) : e.target.value }))} />
          )}</Champ>
        ))}
        {erreur && <Bandeau type="danger">{erreur}</Bandeau>}
      </div>
    </Fenetre>
  );
}

export function Referentiels() {
  const config = useConfig();
  const toast = useToast();
  const services = useRessource('/services/');
  const categories = useRessource('/categories/');
  const [edition, setEdition] = useState(null);
  const svcOptions = (services.donnees || []).map((s) => ({ code: String(s.id), libelle: s.nom }));
  const fait = () => { services.recharger(true); categories.recharger(true); config.recharger(); toast('Référentiel mis à jour (action journalisée).'); };

  const champsService = [
    { cle: 'code', libelle: 'Code', lectureSeule: true, aide: 'Identifiant technique (minuscules, sans espace).' },
    { cle: 'nom', libelle: 'Nom' }, { cle: 'description', libelle: 'Description' }, { cle: 'actif', libelle: 'État', type: 'bool' },
  ];
  const champsCategorie = [
    { cle: 'code', libelle: 'Code', lectureSeule: true }, { cle: 'libelle', libelle: 'Libellé' },
    { cle: 'service_defaut', libelle: 'Service destinataire par défaut', options: svcOptions, vide: 'Aucun (affectation manuelle)', nombre: true },
    { cle: 'gravite_defaut', libelle: 'Gravité par défaut', options: Object.entries(GRAVITES).map(([code, g]) => ({ code, libelle: g.libelle })) },
    { cle: 'couleur', libelle: 'Couleur', type: 'color' }, { cle: 'ordre', libelle: 'Ordre d’affichage', type: 'number' }, { cle: 'actif', libelle: 'État', type: 'bool' },
  ];

  return (
    <>
      <EnTetePage titre="Services & catégories" sousTitre="Administrables sans modifier le code. Pas de suppression : désactivez pour conserver l’historique." />
      <div className="grid gap-5 xl:grid-cols-2">
        <Carte titre="Services" action={<Bouton taille="sm" icone={Plus} onClick={() => setEdition({ type: 'service', initial: { code: '', nom: '', description: '', actif: true } })}>Ajouter</Bouton>} corpsClassName="p-0">
          {services.chargement && !services.donnees ? <Chargement /> : <EtatErreur erreur={services.erreur} onReessayer={services.recharger} />}
          <ul className="divide-y divide-surface-bord">
            {(services.donnees || []).map((s) => (
              <li key={s.id} className="flex items-center justify-between gap-3 px-5 py-3">
                <div><p className="font-semibold">{s.nom}{!s.actif && <span className="ml-2 text-xs text-texte-pale">(désactivé)</span>}</p><p className="text-xs text-texte-doux">{s.code} · {s.description}</p></div>
                <Bouton variante="fantome" taille="sm" icone={Pencil} aria-label={`Modifier ${s.nom}`} onClick={() => setEdition({ type: 'service', initial: s })} />
              </li>
            ))}
          </ul>
        </Carte>
        <Carte titre="Catégories d’incident" action={<Bouton taille="sm" icone={Plus} onClick={() => setEdition({ type: 'categorie', initial: { code: '', libelle: '', service_defaut: null, gravite_defaut: 'moyenne', couleur: '#475569', ordre: 50, actif: true } })}>Ajouter</Bouton>} corpsClassName="p-0">
          <ul className="divide-y divide-surface-bord">
            {(categories.donnees || []).map((c) => (
              <li key={c.id} className="flex items-center justify-between gap-3 px-5 py-3">
                <div className="flex items-center gap-3">
                  <span className="h-3 w-3 rounded-full" style={{ background: c.couleur }} aria-hidden />
                  <div><p className="font-semibold">{c.libelle}{!c.actif && <span className="ml-2 text-xs text-texte-pale">(désactivée)</span>}</p><p className="text-xs text-texte-doux">{c.code} · {c.service_defaut_nom || 'sans service'} · gravité {GRAVITES[c.gravite_defaut]?.libelle.toLowerCase()}</p></div>
                </div>
                <Bouton variante="fantome" taille="sm" icone={Pencil} aria-label={`Modifier ${c.libelle}`} onClick={() => setEdition({ type: 'categorie', initial: c })} />
              </li>
            ))}
          </ul>
        </Carte>
      </div>
      <p className="mt-4 text-xs text-texte-pale">Les poids du score de risque restent ceux du mémoire (méthode de référence) ; une nouvelle catégorie compte pour 1.</p>
      {edition && <Editeur titre={edition.initial.id ? 'Modifier' : 'Ajouter'} chemin={edition.type === 'service' ? '/services/' : '/categories/'}
        champs={edition.type === 'service' ? champsService : champsCategorie} initial={edition.initial} onFermer={() => setEdition(null)} onFait={fait} />}
    </>
  );
}

/* ---------------------------------------------------------- Paramètres */

function EditeurNumeros({ valeur, onChange }) {
  return (
    <div className="space-y-2">
      {valeur.map((n, i) => (
        <div key={i} className="grid gap-2 rounded-xl border border-surface-bord p-3 sm:grid-cols-[1fr_120px_auto]">
          <input className="champ" value={n.service} onChange={(e) => onChange(valeur.map((x, j) => (j === i ? { ...x, service: e.target.value } : x)))} aria-label="Service" />
          <input className="champ" value={n.numero} onChange={(e) => onChange(valeur.map((x, j) => (j === i ? { ...x, numero: e.target.value } : x)))} aria-label="Numéro" />
          <label className="inline-flex items-center gap-2 text-sm"><input type="checkbox" checked={n.verifie} onChange={(e) => onChange(valeur.map((x, j) => (j === i ? { ...x, verifie: e.target.checked } : x)))} /> Vérifié</label>
          <input className="champ sm:col-span-3" value={n.source || ''} placeholder="Source de vérification (obligatoire si vérifié)" onChange={(e) => onChange(valeur.map((x, j) => (j === i ? { ...x, source: e.target.value } : x)))} aria-label="Source" />
        </div>
      ))}
    </div>
  );
}

function EditeurObjet({ valeur, onChange }) {
  return (
    <div className="grid gap-3 sm:grid-cols-2">
      {Object.entries(valeur).map(([k, v]) => (
        <label key={k} className="text-sm">
          <span className="etiquette font-mono text-xs">{k}</span>
          {typeof v === 'boolean'
            ? <span className="inline-flex items-center gap-2"><input type="checkbox" checked={v} onChange={(e) => onChange({ ...valeur, [k]: e.target.checked })} /> {v ? 'Activé' : 'Désactivé'}</span>
            : <input className="champ" type="number" min={0} value={v} onChange={(e) => onChange({ ...valeur, [k]: Number(e.target.value) })} />}
        </label>
      ))}
    </div>
  );
}

function Parametre({ p, onEnregistre }) {
  const toast = useToast();
  const [valeur, setValeur] = useState(p.valeur);
  const [envoi, setEnvoi] = useState(false);
  useEffect(() => setValeur(p.valeur), [p.valeur]);
  const modifie = JSON.stringify(valeur) !== JSON.stringify(p.valeur);
  return (
    <Carte titre={p.cle.replaceAll('_', ' ')} action={<Bouton taille="sm" icone={Save} disabled={!modifie} chargement={envoi} onClick={async () => {
      setEnvoi(true);
      try { await api(`/parametres/${p.cle}/`, { methode: 'PATCH', corps: { valeur } }); toast('Paramètre enregistré (journalisé).'); onEnregistre(); } catch (e) { toast(e.detail, 'erreur'); } finally { setEnvoi(false); }
    }}>Enregistrer</Bouton>}>
      <p className="mb-3 text-sm text-texte-doux">{p.description}</p>
      {Array.isArray(valeur) ? <EditeurNumeros valeur={valeur} onChange={setValeur} /> : <EditeurObjet valeur={valeur} onChange={setValeur} />}
      <p className="mt-3 text-xs text-texte-pale">Dernière modification : {dateHeure(p.date_modification)}{p.modifie_par_nom ? ` par ${p.modifie_par_nom}` : ''}</p>
    </Carte>
  );
}

export function Parametres() {
  const config = useConfig();
  const { donnees, chargement, erreur, recharger } = useRessource('/parametres/');
  return (
    <>
      <EnTetePage titre="Paramètres" sousTitre="Règles métier configurables. Chaque modification est tracée dans le journal d’audit." />
      <EtatErreur erreur={erreur} onReessayer={recharger} />
      {chargement && !donnees ? <Chargement /> : (
        <div className="grid gap-5 xl:grid-cols-2">
          {(donnees || []).map((p) => <Parametre key={p.cle} p={p} onEnregistre={() => { recharger(true); config.recharger(); }} />)}
        </div>
      )}
    </>
  );
}

/* ---------------------------------------------------------- Journal d'audit */

export function Audit() {
  const [filtres, setFiltres] = useState({ action: '', date_debut: '', date_fin: '', page: 1 });
  const { donnees, chargement, erreur, recharger } = useRessource('/audit/', filtres);
  const maj = (k) => (v) => setFiltres((f) => ({ ...f, [k]: v, page: 1 }));
  return (
    <>
      <EnTetePage titre="Journal d’audit" sousTitre="Opérations sensibles : connexions, comptes, affectations, configuration, exports. Lecture seule." />
      <div className="carte mb-4 flex flex-wrap items-end gap-3 p-3">
        <Selecteur aria-label="Action" className="w-auto" valeur={filtres.action} onChange={maj('action')} vide="Toutes actions"
          options={[{ code: 'compte.', libelle: 'Comptes' }, { code: 'admin.', libelle: 'Administration' }, { code: 'dossier.', libelle: 'Dossiers' }, { code: 'config.', libelle: 'Configuration' }, { code: 'export.', libelle: 'Exports' }, { code: 'analyse.', libelle: 'Analyse' }]} />
        <label className="text-xs text-texte-doux">Du<input type="date" className="champ mt-1 py-2" value={filtres.date_debut} onChange={(e) => maj('date_debut')(e.target.value)} /></label>
        <label className="text-xs text-texte-doux">Au<input type="date" className="champ mt-1 py-2" value={filtres.date_fin} onChange={(e) => maj('date_fin')(e.target.value)} /></label>
      </div>
      <EtatErreur erreur={erreur} onReessayer={recharger} />
      <div className="carte overflow-x-auto">
        {chargement && !donnees ? <Chargement /> : (
          <table className="w-full min-w-[720px] text-sm">
            <thead className="bg-surface-douce text-left text-xs uppercase text-texte-doux"><tr><th className="px-4 py-2.5">Date</th><th className="px-4 py-2.5">Acteur</th><th className="px-4 py-2.5">Action</th><th className="px-4 py-2.5">Cible</th><th className="px-4 py-2.5">Détails</th><th className="px-4 py-2.5">IP</th></tr></thead>
            <tbody className="divide-y divide-surface-bord">
              {donnees?.results.map((e) => (
                <tr key={e.id}>
                  <td className="whitespace-nowrap px-4 py-2.5 text-texte-doux">{dateHeure(e.date)}</td>
                  <td className="px-4 py-2.5">{e.acteur_nom || 'Système'}</td>
                  <td className="px-4 py-2.5 font-mono text-xs">{e.action}</td>
                  <td className="px-4 py-2.5 text-texte-doux">{e.cible_type} {e.cible_id}</td>
                  <td className="max-w-xs truncate px-4 py-2.5 font-mono text-xs text-texte-doux" title={JSON.stringify(e.details)}>{Object.keys(e.details || {}).length ? JSON.stringify(e.details) : '—'}</td>
                  <td className="px-4 py-2.5 text-texte-pale">{e.adresse_ip || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        {donnees && <div className="border-t border-surface-bord px-3"><Pagination page={filtres.page} total={donnees.count} onPage={(p) => setFiltres((f) => ({ ...f, page: p }))} /></div>}
      </div>
    </>
  );
}
