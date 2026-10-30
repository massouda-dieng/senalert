import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { useAuth } from '../auth/AuthContext';
import WOLOF from '../../../traductions/wolof.json';

const CLE = 'senalert.langue';
const Contexte = createContext({ langue: 'fr', setLangue: () => {}, t: (texte) => texte });

/** Traduit un texte français ; les valeurs {nom} sont remplacées. Sans traduction : le français. */
export function traduire(langue, texte, valeurs) {
  const brut = (langue === 'wo' && WOLOF[texte]) || texte;
  return valeurs ? brut.replace(/\{(\w+)\}/g, (m, k) => (k in valeurs ? valeurs[k] : m)) : brut;
}

/** Seul l'espace citoyen est traduit : pour les autres rôles et les pages publiques, la langue reste le français. */
export function FournisseurLangue({ children }) {
  const { utilisateur } = useAuth();
  const [choix, setLangueEtat] = useState(() => { try { return localStorage.getItem(CLE) === 'wo' ? 'wo' : 'fr'; } catch { return 'fr'; } });
  const setLangue = useCallback((l) => {
    setLangueEtat(l);
    try { localStorage.setItem(CLE, l); } catch { /* préférence non conservée */ }
  }, []);
  const langue = utilisateur?.role === 'citoyen' ? choix : 'fr';
  useEffect(() => { document.documentElement.lang = langue === 'wo' ? 'wo' : 'fr'; }, [langue]);
  const valeur = useMemo(() => ({ langue, setLangue, t: (texte, valeurs) => traduire(langue, texte, valeurs) }), [langue, setLangue]);
  return <Contexte.Provider value={valeur}>{children}</Contexte.Provider>;
}

export const useLangue = () => useContext(Contexte);

/** Libellé d'une catégorie d'incident dans la langue choisie. */
export function libelleCategorie(langue, code, libelle) {
  return (langue === 'wo' && WOLOF[`categorie:${code}`]) || libelle;
}
