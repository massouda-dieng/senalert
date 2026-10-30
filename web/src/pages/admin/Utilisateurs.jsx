import { Pencil, UserPlus } from 'lucide-react';
import { useState } from 'react';
import { api } from '../../api/client';
import { useRessource } from '../../api/hooks';
import { useAuth } from '../../auth/AuthContext';
import {
  Bandeau, Bouton, Champ, Chargement, EnTetePage, EtatErreur, Fenetre, Pagination, Selecteur, useToast,
} from '../../components/ui';
import { useConfig } from '../../lib/config';
import { dateHeure, ilYa } from '../../lib/format';

function ChoixZones({ valeur, onChange }) {
  const config = useConfig();
  return (
    <div className="grid grid-cols-2 gap-1.5 sm:grid-cols-3">
      {config.regions.map((r) => (
        <label key={r.code} className="inline-flex items-center gap-2 text-sm">
          <input type="checkbox" checked={valeur.includes(r.code)} onChange={(e) => onChange(e.target.checked ? [...valeur, r.code] : valeur.filter((x) => x !== r.code))} />{r.libelle}
        </label>
      ))}
    </div>
  );
}

function FormulaireAgent({ onFermer, onFait, services }) {
  const [f, setF] = useState({ first_name: '', last_name: '', email: '', telephone: '', mot_de_passe_initial: '', service: '', zones: [], matricule: '', fonction: '' });
  const [erreurs, setErreurs] = useState({});
  const [erreur, setErreur] = useState(null);
  const [envoi, setEnvoi] = useState(false);
  const maj = (k) => (e) => setF((x) => ({ ...x, [k]: e?.target ? e.target.value : e }));
  return (
    <Fenetre ouverte large onFermer={onFermer} titre="Créer un compte agent" pied={<>
      <Bouton variante="secondaire" onClick={onFermer}>Annuler</Bouton>
      <Bouton chargement={envoi} onClick={async () => {
        setEnvoi(true); setErreur(null); setErreurs({});
        try { await api('/gestion/utilisateurs/agents/', { methode: 'POST', corps: { ...f, service: Number(f.service) || null } }); onFait(); onFermer(); } catch (e) { setErreurs(e.champs || {}); setErreur(e.detail); } finally { setEnvoi(false); }
      }}>Créer l’agent</Bouton>
    </>}>
      <div className="grid gap-4 sm:grid-cols-2">
        <Champ libelle="Prénom" requis erreur={erreurs.first_name}>{(id) => <input id={id} className="champ" value={f.first_name} onChange={maj('first_name')} />}</Champ>
        <Champ libelle="Nom" requis erreur={erreurs.last_name}>{(id) => <input id={id} className="champ" value={f.last_name} onChange={maj('last_name')} />}</Champ>
        <Champ libelle="E-mail professionnel" requis erreur={erreurs.email}>{(id) => <input id={id} type="email" className="champ" value={f.email} onChange={maj('email')} />}</Champ>
        <Champ libelle="Téléphone" erreur={erreurs.telephone}>{(id) => <input id={id} className="champ" value={f.telephone} onChange={maj('telephone')} />}</Champ>
        <Champ libelle="Service" requis erreur={erreurs.service}>{(id) => <Selecteur id={id} valeur={f.service} onChange={maj('service')} vide="Choisir…" options={services.map((s) => ({ code: String(s.id), libelle: s.nom }))} />}</Champ>
        <Champ libelle="Mot de passe initial" requis aide="L’agent devra le changer à sa première connexion." erreur={erreurs.mot_de_passe_initial}>{(id) => <input id={id} type="password" autoComplete="new-password" className="champ" value={f.mot_de_passe_initial} onChange={maj('mot_de_passe_initial')} />}</Champ>
        <Champ libelle="Matricule">{(id) => <input id={id} className="champ" value={f.matricule} onChange={maj('matricule')} />}</Champ>
        <Champ libelle="Fonction">{(id) => <input id={id} className="champ" value={f.fonction} onChange={maj('fonction')} />}</Champ>
      </div>
      <div className="mt-4"><p className="etiquette">Zones de couverture <span className="text-sos">*</span></p><ChoixZones valeur={f.zones} onChange={maj('zones')} />{erreurs.zones && <p className="mt-1 text-xs text-red-700">{erreurs.zones}</p>}</div>
      {erreur && <Bandeau type="danger" className="mt-4">{erreur}</Bandeau>}
    </Fenetre>
  );
}

function FormulaireModification({ u, onFermer, onFait, services }) {
  const [f, setF] = useState({ role: u.role, is_active: u.is_active, service: u.profil_agent?.service ? String(u.profil_agent.service) : '', zones: u.profil_agent?.zones || [] });
  const [erreur, setErreur] = useState(null);
  const [envoi, setEnvoi] = useState(false);
  return (
    <Fenetre ouverte large onFermer={onFermer} titre={`Modifier ${u.first_name || u.username}`} pied={<>
      <Bouton variante="secondaire" onClick={onFermer}>Annuler</Bouton>
      <Bouton chargement={envoi} onClick={async () => {
        setEnvoi(true); setErreur(null);
        const corps = { role: f.role, is_active: f.is_active };
        if (f.role === 'agent') Object.assign(corps, { service: f.service ? Number(f.service) : null, zones: f.zones });
        try { await api(`/gestion/utilisateurs/${u.id}/`, { methode: 'PATCH', corps }); onFait(); onFermer(); } catch (e) { setErreur(e.detail); } finally { setEnvoi(false); }
      }}>Enregistrer</Bouton>
    </>}>
      <div className="space-y-4">
        <Bandeau type="info">Un changement de rôle ou une désactivation ferme toutes les sessions de l’utilisateur. Le rôle superadministrateur ne s’attribue qu’en ligne de commande sur le serveur.</Bandeau>
        <div className="grid gap-4 sm:grid-cols-2">
          <Champ libelle="Rôle">{(id) => <Selecteur id={id} vide={null} valeur={f.role} onChange={(v) => setF((x) => ({ ...x, role: v }))} options={[{ code: 'citoyen', libelle: 'Citoyen' }, { code: 'agent', libelle: 'Agent de secours' }]} />}</Champ>
          <Champ libelle="Compte">{(id) => <Selecteur id={id} vide={null} valeur={f.is_active ? '1' : '0'} onChange={(v) => setF((x) => ({ ...x, is_active: v === '1' }))} options={[{ code: '1', libelle: 'Actif' }, { code: '0', libelle: 'Désactivé' }]} />}</Champ>
        </div>
        {f.role === 'agent' && <>
          <Champ libelle="Service">{(id) => <Selecteur id={id} valeur={f.service} onChange={(v) => setF((x) => ({ ...x, service: v }))} vide="Aucun" options={services.map((s) => ({ code: String(s.id), libelle: s.nom }))} />}</Champ>
          <div><p className="etiquette">Zones</p><ChoixZones valeur={f.zones} onChange={(z) => setF((x) => ({ ...x, zones: z }))} /></div>
        </>}
        {erreur && <Bandeau type="danger">{erreur}</Bandeau>}
      </div>
    </Fenetre>
  );
}

export default function Utilisateurs() {
  const { utilisateur: moi } = useAuth();
  const config = useConfig();
  const toast = useToast();
  const [filtres, setFiltres] = useState({ role: '', is_active: '', q: '', zone: '', page: 1 });
  const [creation, setCreation] = useState(false);
  const [edition, setEdition] = useState(null);
  const liste = useRessource('/gestion/utilisateurs/', filtres);
  const stats = useRessource('/gestion/utilisateurs/statistiques/');
  const services = useRessource('/services/');
  const svc = (services.donnees || []).filter((s) => s.actif);
  const maj = (k) => (v) => setFiltres((f) => ({ ...f, [k]: v, page: 1 }));
  const recharger = () => { liste.recharger(true); stats.recharger(true); toast('Modifications enregistrées.'); };

  return (
    <>
      <EnTetePage titre="Utilisateurs" sousTitre={stats.donnees ? `${stats.donnees.citoyens} citoyens · ${stats.donnees.agents_actifs}/${stats.donnees.agents} agents actifs · ${stats.donnees.superadmins} superadmin(s)` : ''}
        actions={<Bouton icone={UserPlus} onClick={() => setCreation(true)}>Créer un agent</Bouton>} />
      <div className="carte mb-4 flex flex-wrap gap-3 p-3">
        <input className="champ w-56 py-2" placeholder="Nom, e-mail, téléphone…" aria-label="Recherche" onKeyDown={(e) => e.key === 'Enter' && maj('q')(e.currentTarget.value)} onBlur={(e) => maj('q')(e.currentTarget.value)} />
        <Selecteur aria-label="Rôle" className="w-auto" valeur={filtres.role} onChange={maj('role')} vide="Tous rôles" options={config.roles} />
        <Selecteur aria-label="État" className="w-auto" valeur={filtres.is_active} onChange={maj('is_active')} vide="Tous états" options={[{ code: 'true', libelle: 'Actifs' }, { code: 'false', libelle: 'Désactivés' }]} />
        <Selecteur aria-label="Zone" className="w-auto" valeur={filtres.zone} onChange={maj('zone')} vide="Toutes zones" options={config.regions} />
      </div>
      <EtatErreur erreur={liste.erreur} onReessayer={liste.recharger} />
      <div className="carte overflow-x-auto">
        {liste.chargement && !liste.donnees ? <Chargement /> : (
          <table className="w-full min-w-[760px] text-sm">
            <thead className="bg-surface-douce text-left text-xs uppercase text-texte-doux">
              <tr><th className="px-4 py-2.5">Utilisateur</th><th className="px-4 py-2.5">Rôle</th><th className="px-4 py-2.5">Service · zones</th><th className="px-4 py-2.5">Interventions</th><th className="px-4 py-2.5">Dernière connexion</th><th className="px-4 py-2.5" /></tr>
            </thead>
            <tbody className="divide-y divide-surface-bord">
              {liste.donnees?.results.map((u) => (
                <tr key={u.id} className={u.is_active ? '' : 'opacity-60'}>
                  <td className="px-4 py-3"><p className="font-semibold">{`${u.first_name} ${u.last_name}`.trim() || u.username}</p><p className="text-xs text-texte-doux">{u.email}</p></td>
                  <td className="px-4 py-3">{u.role_libelle}{!u.is_active && <span className="ml-2 rounded bg-slate-200 px-1.5 text-[10px] font-bold uppercase">désactivé</span>}</td>
                  <td className="px-4 py-3 text-texte-doux">{u.profil_agent ? `${u.profil_agent.service_nom || '—'} · ${(u.profil_agent.zones || []).map((z) => config.region(z)?.libelle || z).join(', ') || 'aucune zone'}` : '—'}</td>
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
      {creation && <FormulaireAgent services={svc} onFermer={() => setCreation(false)} onFait={recharger} />}
      {edition && <FormulaireModification u={edition} services={svc} onFermer={() => setEdition(null)} onFait={recharger} />}
    </>
  );
}
