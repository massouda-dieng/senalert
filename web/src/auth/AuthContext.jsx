import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { api, aUneSession, effacerJetons, enregistrerJetons, refreshActuel, surSessionExpiree } from '../api/client';

const Contexte = createContext(null);

export const ESPACE_PAR_ROLE = { citoyen: '/citoyen', agent: '/agent', superadmin: '/supervision' };

export function FournisseurAuth({ children }) {
  const [utilisateur, setUtilisateur] = useState(null);
  const [initialise, setInitialise] = useState(false);
  const [sessionExpiree, setSessionExpiree] = useState(false);

  const ouvrirSession = useCallback((reponse) => {
    enregistrerJetons(reponse);
    setUtilisateur(reponse.utilisateur);
    setSessionExpiree(false);
    return reponse.utilisateur;
  }, []);

  const rechargerProfil = useCallback(async () => {
    const u = await api('/auth/profil/');
    setUtilisateur(u);
    return u;
  }, []);

  useEffect(() => {
    (async () => {
      if (aUneSession()) {
        try { await rechargerProfil(); } catch { effacerJetons(); }
      }
      setInitialise(true);
    })();
    return surSessionExpiree(() => { setUtilisateur(null); setSessionExpiree(true); });
  }, [rechargerProfil]);

  const valeur = useMemo(() => ({
    utilisateur,
    initialise,
    sessionExpiree,
    connexion: async (identifiant, motDePasse) =>
      ouvrirSession(await api('/auth/connexion/', { methode: 'POST', corps: { username: identifiant, password: motDePasse }, auth: false })),
    inscription: async (donnees) =>
      ouvrirSession(await api('/auth/inscription/', { methode: 'POST', corps: donnees, auth: false })),
    connexionGoogle: async (idToken) =>
      ouvrirSession(await api('/auth/google/', { methode: 'POST', corps: { id_token: idToken }, auth: false })),
    deconnexion: async (tout = false) => {
      try { await api('/auth/deconnexion/', { methode: 'POST', corps: tout ? { tout: true } : { refresh: refreshActuel() } }); } catch { /* session déjà close */ }
      effacerJetons();
      setUtilisateur(null);
    },
    ouvrirSession,
    rechargerProfil,
    setUtilisateur,
  }), [utilisateur, initialise, sessionExpiree, ouvrirSession, rechargerProfil]);

  return <Contexte.Provider value={valeur}>{children}</Contexte.Provider>;
}

export const useAuth = () => useContext(Contexte);
