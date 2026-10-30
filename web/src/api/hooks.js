import { useCallback, useEffect, useRef, useState } from 'react';
import { api } from './client';

/**
 * Charge une ressource et expose { donnees, chargement, erreur, recharger, derniereSynchro }.
 * `intervalle` (ms) active un rafraîchissement périodique (pas de temps réel push côté web).
 */
export function useRessource(chemin, params, { intervalle = 0, actif = true } = {}) {
  const [etat, setEtat] = useState({ donnees: null, chargement: Boolean(actif && chemin), erreur: null, derniereSynchro: null });
  const cleParams = JSON.stringify(params || {});
  const ref = useRef(0);

  const recharger = useCallback(async (silencieux = false) => {
    if (!chemin || !actif) return;
    const id = ++ref.current;
    if (!silencieux) setEtat((e) => ({ ...e, chargement: true, erreur: null }));
    try {
      const donnees = await api(chemin, { params: JSON.parse(cleParams) });
      if (id === ref.current) setEtat({ donnees, chargement: false, erreur: null, derniereSynchro: new Date() });
    } catch (erreur) {
      if (id === ref.current) setEtat((e) => ({ ...e, chargement: false, erreur }));
    }
  }, [chemin, cleParams, actif]);

  useEffect(() => { recharger(); }, [recharger]);
  useEffect(() => {
    if (!intervalle) return undefined;
    const t = setInterval(() => { if (document.visibilityState === 'visible') recharger(true); }, intervalle);
    return () => clearInterval(t);
  }, [intervalle, recharger]);

  return { ...etat, recharger, setDonnees: (d) => setEtat((e) => ({ ...e, donnees: typeof d === 'function' ? d(e.donnees) : d })) };
}
