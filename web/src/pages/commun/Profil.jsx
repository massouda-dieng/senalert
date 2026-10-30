import { KeyRound, LogOut, Save, ShieldCheck, Trash2 } from 'lucide-react';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../../api/client';
import { useAuth } from '../../auth/AuthContext';
import { Bandeau, Bouton, Carte, Champ, EnTetePage, Fenetre, Selecteur, useToast } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { choisirTheme, themeChoisi } from '../../lib/theme';

const PREFS = [
  ['notifications_push', 'Notifications push sur mobile', ['citoyen', 'agent', 'superadmin']],
  ['notifications_statut', 'Être notifié des changements de statut de mes dossiers', ['citoyen']],
];

export default function Profil() {
  const { utilisateur, setUtilisateur, ouvrirSession, deconnexion } = useAuth();
  const config = useConfig();
  const toast = useToast();
  const navigate = useNavigate();
  const [f, setF] = useState({ first_name: utilisateur.first_name, last_name: utilisateur.last_name, email: utilisateur.email, telephone: utilisateur.telephone, region: utilisateur.region });
  const [mdp, setMdp] = useState({ ancien: '', nouveau: '' });
  const [erreurs, setErreurs] = useState({});
  const [envoi, setEnvoi] = useState(null);
  const [suppression, setSuppression] = useState(false);

  const enregistrer = async (corps, cle = 'profil') => {
    setEnvoi(cle); setErreurs({});
    try { setUtilisateur(await api('/auth/profil/', { methode: 'PATCH', corps })); toast('Profil mis à jour.'); } catch (e) { setErreurs(e.champs || {}); toast(e.detail, 'erreur'); } finally { setEnvoi(null); }
  };

  return (
    <div className="mx-auto max-w-3xl space-y-5">
      <EnTetePage titre="Profil et sécurité" sousTitre={`${utilisateur.role_libelle} — le rôle est attribué par SenAlert et ne peut pas être modifié ici.`} />
      <Carte titre="Informations personnelles">
        <div className="grid gap-4 sm:grid-cols-2">
          <Champ libelle="Prénom" erreur={erreurs.first_name}>{(id) => <input id={id} className="champ" value={f.first_name} onChange={(e) => setF({ ...f, first_name: e.target.value })} />}</Champ>
          <Champ libelle="Nom" erreur={erreurs.last_name}>{(id) => <input id={id} className="champ" value={f.last_name} onChange={(e) => setF({ ...f, last_name: e.target.value })} />}</Champ>
          <Champ libelle="E-mail" erreur={erreurs.email}>{(id) => <input id={id} type="email" className="champ" value={f.email} onChange={(e) => setF({ ...f, email: e.target.value })} />}</Champ>
          <Champ libelle="Téléphone" aide="Visible uniquement par l’agent affecté à vos dossiers." erreur={erreurs.telephone}>{(id) => <input id={id} className="champ" value={f.telephone} onChange={(e) => setF({ ...f, telephone: e.target.value })} />}</Champ>
          <Champ libelle="Région" erreur={erreurs.region}>{(id) => <Selecteur id={id} valeur={f.region} onChange={(v) => setF({ ...f, region: v })} vide="—" options={config.regions} />}</Champ>
        </div>
        <div className="mt-4 flex justify-end"><Bouton icone={Save} chargement={envoi === 'profil'} onClick={() => enregistrer(f)}>Enregistrer</Bouton></div>
      </Carte>

      <Carte titre="Préférences">
        <div className="space-y-3">
          <label className="flex items-center justify-between gap-4 text-sm">Apparence
            <select className="champ w-auto py-1.5" defaultValue={themeChoisi()} onChange={(e) => { choisirTheme(e.target.value); window.location.reload(); }}>
              <option value="systeme">Selon le système</option><option value="clair">Clair</option><option value="sombre">Sombre</option>
            </select>
          </label>
          {PREFS.filter(([, , roles]) => roles.includes(utilisateur.role)).map(([k, l]) => (
            <label key={k} className="flex items-center justify-between gap-4 text-sm">{l}
              <input type="checkbox" className="h-5 w-5" checked={Boolean(utilisateur.preferences?.[k])} onChange={(e) => enregistrer({ preferences: { [k]: e.target.checked } }, k)} />
            </label>
          ))}
        </div>
      </Carte>

      <Carte titre={utilisateur.a_mot_de_passe ? 'Changer de mot de passe' : 'Définir un mot de passe'}>
        {utilisateur.doit_changer_mot_de_passe && <Bandeau type="alerte" className="mb-4">Votre compte utilise un mot de passe initial fourni par l’administrateur : remplacez-le.</Bandeau>}
        <div className="grid gap-4 sm:grid-cols-2">
          {utilisateur.a_mot_de_passe && <Champ libelle="Mot de passe actuel" erreur={erreurs.ancien}>{(id) => <input id={id} type="password" autoComplete="current-password" className="champ" value={mdp.ancien} onChange={(e) => setMdp({ ...mdp, ancien: e.target.value })} />}</Champ>}
          <Champ libelle="Nouveau mot de passe" erreur={erreurs.nouveau} aide="8 caractères minimum.">{(id) => <input id={id} type="password" autoComplete="new-password" className="champ" value={mdp.nouveau} onChange={(e) => setMdp({ ...mdp, nouveau: e.target.value })} />}</Champ>
        </div>
        <div className="mt-4 flex justify-end">
          <Bouton icone={KeyRound} chargement={envoi === 'mdp'} disabled={!mdp.nouveau} onClick={async () => {
            setEnvoi('mdp'); setErreurs({});
            try { ouvrirSession(await api('/auth/mot-de-passe/', { methode: 'POST', corps: mdp })); setMdp({ ancien: '', nouveau: '' }); toast('Mot de passe modifié. Vos autres sessions ont été fermées.'); } catch (e) { setErreurs(e.champs || {}); toast(e.detail, 'erreur'); } finally { setEnvoi(null); }
          }}>Mettre à jour</Bouton>
        </div>
      </Carte>

      <Carte titre="Sessions et compte">
        <div className="space-y-4 text-sm">
          <p className="flex items-center gap-2"><ShieldCheck className="h-4 w-4 text-succes" /> Connexion Google : {utilisateur.google_lie ? 'liée à ce compte' : 'non liée'}.</p>
          <div className="flex flex-wrap gap-2">
            <Bouton variante="secondaire" icone={LogOut} onClick={async () => { await deconnexion(true); navigate('/connexion'); }}>Se déconnecter de tous les appareils</Bouton>
            {utilisateur.role !== 'superadmin' && <Bouton variante="secondaire" className="text-red-700" icone={Trash2} onClick={() => setSuppression(true)}>Supprimer mon compte</Bouton>}
          </div>
          <p className="text-xs text-texte-pale">Vos données personnelles sont traitées conformément à la loi sénégalaise n° 2008-12. La suppression anonymise votre compte ; les dossiers restent dans les statistiques sans lien avec votre identité.</p>
        </div>
      </Carte>
      <Suppression ouverte={suppression} onFermer={() => setSuppression(false)} motDePasse={utilisateur.a_mot_de_passe} onFait={async () => { await deconnexion(); navigate('/connexion'); }} />
    </div>
  );
}

function Suppression({ ouverte, onFermer, motDePasse, onFait }) {
  const [f, setF] = useState({ mot_de_passe: '', confirmation: '' });
  const [erreur, setErreur] = useState(null);
  const [envoi, setEnvoi] = useState(false);
  return (
    <Fenetre ouverte={ouverte} onFermer={onFermer} titre="Supprimer mon compte" pied={<>
      <Bouton variante="secondaire" onClick={onFermer}>Annuler</Bouton>
      <Bouton variante="danger" chargement={envoi} disabled={f.confirmation !== 'SUPPRIMER'} onClick={async () => {
        setEnvoi(true); setErreur(null);
        try { await api('/auth/profil/', { methode: 'DELETE', corps: f }); onFait(); } catch (e) { setErreur(e.detail); } finally { setEnvoi(false); }
      }}>Supprimer définitivement</Bouton>
    </>}>
      <div className="space-y-4">
        <p className="text-sm text-texte-doux">Cette action est irréversible : vous serez déconnecté partout et ne pourrez plus vous reconnecter avec ce compte.</p>
        {motDePasse && <Champ libelle="Mot de passe">{(id) => <input id={id} type="password" className="champ" value={f.mot_de_passe} onChange={(e) => setF({ ...f, mot_de_passe: e.target.value })} />}</Champ>}
        <Champ libelle="Tapez SUPPRIMER pour confirmer">{(id) => <input id={id} className="champ" value={f.confirmation} onChange={(e) => setF({ ...f, confirmation: e.target.value })} />}</Champ>
        {erreur && <Bandeau type="danger">{erreur}</Bandeau>}
      </div>
    </Fenetre>
  );
}
