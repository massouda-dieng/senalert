import { createContext, useContext, useMemo } from 'react';
import { useRessource } from '../api/hooks';

const Contexte = createContext(null);

/** Charge /api/configuration/ (catégories, régions, numéros vérifiés, fonctionnalités). */
export function FournisseurConfig({ children }) {
  const { donnees, erreur, recharger } = useRessource('/configuration/');
  const valeur = useMemo(() => {
    const c = donnees || { categories: [], regions: [], roles: [], statuts: [], gravites: [], numeros_urgence: [], fonctionnalites: {} };
    const categorie = (code) => c.categories.find((x) => x.code === code);
    const region = (code) => c.regions.find((x) => x.code === code);
    return { ...c, pret: Boolean(donnees), erreur, recharger, categorie, region };
  }, [donnees, erreur, recharger]);
  return <Contexte.Provider value={valeur}>{children}</Contexte.Provider>;
}

export const useConfig = () => useContext(Contexte);
