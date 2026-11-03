import { Pencil, ShieldPlus, UserPlus } from 'lucide-react';
import { useState } from 'react';
import { api } from '../../api/client';
import { useRessource } from '../../api/hooks';
import { useAuth } from '../../auth/AuthContext';
import {
  Bandeau, Bouton, Champ, Chargement, EnTetePage, EtatErreur, Fenetre, Pagination, Selecteur, useToast,
} from '../../components/ui';
import { useConfig } from '../../lib/config';
import { dateHeure, ilYa } from '../../lib/format';

/** Choix d'une structure (caserne, commissariat, hôpital, agence) par service et par nom. */
export function ChoixStructure({ id, valeur, onChange, services }) {
  const [service, setService] = useState('');
  const [q, setQ] = useState('');
  const structures = useRessource(service || q.length >= 2 ? '/structures/' : null, { service: service || undefined, q: q || undefined, actif: true });
  const liste = (structures.donnees || []).slice(0, 80);
  return (
    <div className="space-y-2">
      <div className="grid gap-2 sm:grid-cols-2">
        <Selecteur aria-label="Service de la structure" valeur={service} onChange={setService} vide="Tous les services"
          options={services.map((s) => ({ code: s.code, libelle: s.nom }))} />
        <input className="champ" placeholder="Nom (ex. Médina, Thiès)…" aria-label="Rechercher une structure" value={q} onChange={(e) => setQ(e.target.value)} />
      </div>
      {structures.chargement ? <Chargement className="py-2" /> : (
        <Selecteur id={id} valeur={valeur} onChange={onChange} vide={service || q ? `Choisir parmi ${liste.length} structure(s)…` : 'Choisissez d’abord un service ou tapez un nom'}
          options={liste.map((s) => ({ code: String(s.id), libelle: `${s.nom} — ${s.region_libelle}${s.position_approximative ? ' (position à confirmer)' : ''}` }))} />
      )}
    </div>
  );
}

/** Création d'un agent (par son superviseur, dans sa structure) ou d'un superviseur de structure (national). */
function FormulaireCompte({ type, national, onFermer, onFait, services }) {
  const agent = type === 'agent';
  const [f, setF] = useState({ first_name: '', last_name: '', email: '', telephone: '', mot_de_passe_initial: '', structure: '', matricule: '', fonction: '' });
  const [erreurs, setErreurs] = useState({});
  const [erreur, setErreur] = useState(null);
  const [envoi, setEnvoi] = useState(false);
  const maj = (k) => (e) => setF((x) => ({ ...x, [k]: e?.target ? e.target.value : e }));
  return (
    <Fenetre ouverte large onFermer={onFermer} titre={agent ? 'Ajouter un agent' : 'Créer un superviseur de structure'} pied={<>
      <Bouton variante="secondaire" onClick={onFermer}>Annuler</Bouton>
      <Bouton chargement={envoi} onClick={async () => {
        setEnvoi(true); setErreur(null); setErreurs({});
        const corps = { ...f, structure: Number(f.structure) || undefined };
        try {
          await api(`/gestion/utilisateurs/${agent ? 'agents' : 'superviseurs'}/`, { methode: 'POST', corps });
          onFait(); onFermer();
        } catch (e) { setErreurs(e.champs || {}); setErreur(e.detail); } finally { setEnvoi(false); }
      }}>{agent ? 'Ajouter l’agent' : 'Créer le superviseur'}</Bouton>
    </>}>
      {agent && !national && <Bandeau type="info" className="mb-4">L’agent est rattaché à votre structure. Il sera proposé aux citoyens dès qu’il est disponible.</Bandeau>}
      <div className="grid gap-4 sm:grid-cols-2">
        <Champ libelle="Prénom" requis erreur={erreurs.first_name} aide={agent ? 'Seul le prénom est montré aux citoyens.' : undefined}>{(id) => <input id={id} className="champ" value={f.first_name} onChange={maj('first_name')} />}</Champ>
        <Champ libelle="Nom" requis erreur={erreurs.last_name}>{(id) => <input id={id} className="champ" value={f.last_name} onChange={maj('last_name')} />}</Champ>
        <Champ libelle="E-mail professionnel" requis erreur={erreurs.email}>{(id) => <input id={id} type="email" className="champ" value={f.email} onChange={maj('email')} />}</Champ>
        <Champ libelle="Téléphone" erreur={erreurs.telephone}>{(id) => <input id={id} className="champ" value={f.telephone} onChange={maj('telephone')} />}</Champ>
        <Champ libelle="Mot de passe initial" requis aide="À changer à la première connexion." erreur={erreurs.mot_de_passe_initial}>{(id) => <input id={id} type="password" autoComplete="new-password" className="champ" value={f.mot_de_passe_initial} onChange={maj('mot_de_passe_initial')} />}</Champ>
        {agent && <Champ libelle="Fonction" aide="Ex. sapeur-pompier, infirmière, technicien.">{(id) => <input id={id} className="champ" value={f.fonction} onChange={maj('fonction')} />}</Champ>}
        {agent && <Champ libelle="Matricule">{(id) => <input id={id} className="champ" value={f.matricule} onChange={maj('matricule')} />}</Champ>}
      </div>
      {national && (
        <div className="mt-4"><Champ libelle="Structure" requis erreur={erreurs.structure}>{(id) => <ChoixStructure id={id} valeur={f.structure} onChange={maj('structure')} services={services} />}</Champ></div>
      )}
      {erreur && <Bandeau type="danger" className="mt-4">{erreur}</Bandeau>}
    </Fenetre>
  );
}

function FormulaireModification({ u, national, onFermer, onFait, services }) {
  const [f, setF] = useState({
    role: u.role, is_active: u.is_active, structure: u.structure ? String(u.structure) : '',
    fonction: u.profil_agent?.fonction || '', disponible: u.profil_agent?.disponible ?? true,
  });
  const [erreur, setErreur] = useState(null);
  const [envoi, setEnvoi] = useState(false);
  const agent = f.role === 'agent';
  return (
    <Fenetre ouverte large onFermer={onFermer} titre={`Modifier ${u.first_name || u.username}`} pied={<>
      <Bouton variante="secondaire" onClick={onFermer}>Annuler</Bouton>
      <Bouton chargement={envoi} onClick={async () => {
        setEnvoi(true); setErreur(null);
        const corps = { is_active: f.is_active };
        if (national) Object.assign(corps, { role: f.role, structure: f.structure ? Number(f.structure) : null });
        if (agent) Object.assign(corps, { fonction: f.fonction, disponible: f.disponible });
        try { await api(`/gestion/utilisateurs/${u.id}/`, { methode: 'PATCH', corps }); onFait(); onFermer(); } catch (e) { setErreur(e.detail); } finally { setEnvoi(false); }
      }}>Enregistrer</Bouton>
    </>}>
      <div className="space-y-4">
        <Bandeau type="info">Une désactivation{national ? ', un changement de rôle ou de structure' : ''} ferme toutes les sessions de l’utilisateur.</Bandeau>
        <div className="grid gap-4 sm:grid-cols-2">
          {national && <Champ libelle="Rôle">{(id) => <Selecteur id={id} vide={null} valeur={f.role} onChange={(v) => setF((x) => ({ ...x, role: v }))} options={[{ code: 'citoyen', libelle: 'Citoyen' }, { code: 'agent', libelle: 'Agent de secours' }, { code: 'superviseur', libelle: 'Superviseur de structure' }]} />}</Champ>}
          <Champ libelle="Compte">{(id) => <Selecteur id={id} vide={null} valeur={f.is_active ? '1' : '0'} onChange={(v) => setF((x) => ({ ...x, is_active: v === '1' }))} options={[{ code: '1', libelle: 'Actif' }, { code: '0', libelle: 'Désactivé' }]} />}</Champ>
          {agent && <Champ libelle="Disponibilité">{(id) => <Selecteur id={id} vide={null} valeur={f.disponible ? '1' : '0'} onChange={(v) => setF((x) => ({ ...x, disponible: v === '1' }))} options={[{ code: '1', libelle: 'Disponible' }, { code: '0', libelle: 'Indisponible' }]} />}</Champ>}
          {agent && <Champ libelle="Fonction">{(id) => <input id={id} className="champ" value={f.fonction} onChange={(e) => setF((x) => ({ ...x, fonction: e.target.value }))} />}</Champ>}
        </div>
        {national && f.role !== 'citoyen' && (
          <Champ libelle="Structure" aide={u.structure_nom ? `Actuelle : ${u.structure_nom}` : undefined}>{(id) => <ChoixStructure id={id} valeur={f.structure} onChange={(v) => setF((x) => ({ ...x, structure: v }))} services={services} />}</Champ>
        )}
        {erreur && <Bandeau type="danger">{erreur}</Bandeau>}
      </div>
    </Fenetre>
  );
}

export default function Utilisateurs() {
  const { utilisateur: moi } = useAuth();
  const national = moi.role === 'superadmin';
  const config = useConfig();
  const toast = useToast();
  const [filtres, setFiltres] = useState({ role: '', is_active: '', q: '', page: 1 });
  const [creation, setCreation] = useState(null);
  const [edition, setEdition] = useState(null);
  const liste = useRessource('/gestion/utilisateurs/', filtres);
  const stats = useRessource('/gestion/utilisateurs/statistiques/');
  const services = useRessource('/services/');
  const svc = (services.donnees || []).filter((s) => s.actif);
  const maj = (k) => (v) => setFiltres((f) => ({ ...f, [k]: v, page: 1 }));
  const recharger = () => { liste.recharger(true); stats.recharger(true); toast('Modifications enregistrées.'); };
  const st = stats.donnees;
  const sousTitre = !st ? '' : national
    ? `${st.citoyens} citoyens · ${st.agents_actifs}/${st.agents} agents actifs · ${st.superviseurs} superviseurs de structure`
    : `${moi.structure_nom || 'Ma structure'} · ${st.agents_disponibles}/${st.agents} agents disponibles`;

  return (
    <>
      <EnTetePage titre={national ? 'Utilisateurs' : 'Mes agents'} sousTitre={sousTitre} actions={<>
        {national && <Bouton variante="secondaire" icone={ShieldPlus} onClick={() => setCreation('superviseur')}>Créer un superviseur</Bouton>}
        <Bouton icone={UserPlus} onClick={() => setCreation('agent')}>Ajouter un agent</Bouton>
      </>} />
      <div className="carte mb-4 flex flex-wrap gap-3 p-3">
        <input className="champ w-56 py-2" placeholder="Nom, e-mail, téléphone…" aria-label="Recherche" onKeyDown={(e) => e.key === 'Enter' && maj('q')(e.currentTarget.value)} onBlur={(e) => maj('q')(e.currentTarget.value)} />
        {national && <Selecteur aria-label="Rôle" className="w-auto" valeur={filtres.role} onChange={maj('role')} vide="Tous rôles" options={config.roles} />}
        <Selecteur aria-label="État" className="w-auto" valeur={filtres.is_active} onChange={maj('is_active')} vide="Tous états" options={[{ code: 'true', libelle: 'Actifs' }, { code: 'false', libelle: 'Désactivés' }]} />
      </div>
      <EtatErreur erreur={liste.erreur} onReessayer={liste.recharger} />
      <div className="carte overflow-x-auto">
        {liste.chargement && !liste.donnees ? <Chargement /> : (
          <table className="w-full min-w-[760px] text-sm">
            <thead className="bg-surface-douce text-left text-xs uppercase text-texte-doux">
              <tr><th className="px-4 py-2.5">Utilisateur</th><th className="px-4 py-2.5">Rôle</th><th className="px-4 py-2.5">Structure</th><th className="px-4 py-2.5">Interventions</th><th className="px-4 py-2.5">Dernière connexion</th><th className="px-4 py-2.5" /></tr>
            </thead>
            <tbody className="divide-y divide-surface-bord">
              {liste.donnees?.results.map((u) => (
                <tr key={u.id} className={u.is_active ? '' : 'opacity-60'}>
                  <td className="px-4 py-3"><p className="font-semibold">{`${u.first_name} ${u.last_name}`.trim() || u.username}</p><p className="text-xs text-texte-doux">{u.email}</p></td>
                  <td className="px-4 py-3">
                    {u.role === 'agent' && u.profil_agent?.fonction ? u.profil_agent.fonction : u.role_libelle}
                    {!u.is_active && <span className="ml-2 rounded bg-slate-200 px-1.5 text-[10px] font-bold uppercase">désactivé</span>}
                    {u.role === 'agent' && u.is_active && (u.profil_agent?.disponible
                      ? <span className="ml-2 rounded bg-succes-clair px-1.5 text-[10px] font-bold uppercase text-succes">disponible</span>
                      : <span className="ml-2 rounded bg-alerte-clair px-1.5 text-[10px] font-bold uppercase text-alerte">indisponible</span>)}
                  </td>
                  <td className="px-4 py-3 text-texte-doux">{u.structure_nom || '—'}</td>
                  <td className="px-4 py-3 tabular-nums">{u.role === 'agent' ? u.nb_interventions : '—'}</td>
                  <td className="px-4 py-3 text-texte-doux" title={dateHeure(u.last_login)}>{u.last_login ? ilYa(u.last_login) : 'Jamais'}</td>
                  <td className="px-4 py-3 text-right">{u.role !== 'superadmin' && u.id !== moi.id && <Bouton variante="fantome" taille="sm" icone={Pencil} onClick={() => setEdition(u)} aria-label={`Modifier ${u.username}`}>Modifier</Bouton>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        {liste.donnees && <div className="border-t border-surface-bord px-3"><Pagination page={filtres.page} total={liste.donnees.count} onPage={(p) => setFiltres((f) => ({ ...f, page: p }))} /></div>}
      </div>
      {creation && <FormulaireCompte type={creation} national={national} services={svc} onFermer={() => setCreation(null)} onFait={recharger} />}
      {edition && <FormulaireModification u={edition} national={national} services={svc} onFermer={() => setEdition(null)} onFait={recharger} />}
    </>
  );
}
