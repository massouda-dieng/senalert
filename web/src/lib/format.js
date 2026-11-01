import { COULEURS } from './couleurs';

const { statuts: S, gravites: G } = COULEURS;

export const STATUTS = {
  nouveau: { libelle: 'Nouveau', classe: 'bg-statut-nouveau-fond text-statut-nouveau ring-statut-nouveau/20', point: S.nouveau.point },
  affecte: { libelle: 'Affecté', classe: 'bg-statut-affecte-fond text-statut-affecte ring-statut-affecte/20', point: S.affecte.point },
  accepte: { libelle: 'Pris en charge', classe: 'bg-statut-accepte-fond text-statut-accepte ring-statut-accepte/20', point: S.accepte.point },
  en_cours: { libelle: 'En cours', classe: 'bg-statut-en_cours-fond text-statut-en_cours ring-statut-en_cours/20', point: S.en_cours.point },
  resolu: { libelle: 'Résolu', classe: 'bg-statut-resolu-fond text-statut-resolu ring-statut-resolu/20', point: S.resolu.point },
  refuse: { libelle: 'Rejeté', classe: 'bg-statut-refuse-fond text-statut-refuse ring-statut-refuse/20', point: S.refuse.point },
  annule: { libelle: 'Annulé', classe: 'bg-statut-annule-fond text-statut-annule ring-statut-annule/20', point: S.annule.point },
};

export const GRAVITES = {
  faible: { libelle: 'Faible', classe: 'text-slate-600 bg-slate-100', couleur: G.faible },
  moyenne: { libelle: 'Moyenne', classe: 'text-marque-700 bg-marque-50', couleur: G.moyenne },
  elevee: { libelle: 'Élevée', classe: 'text-alerte bg-alerte-clair', couleur: G.elevee },
  critique: { libelle: 'Critique', classe: 'text-white bg-sos-fonce', couleur: G.critique },
};

/** Du plus urgent au moins urgent : ordre d'affichage des files de travail. */
export const ORDRE_GRAVITE = ['critique', 'elevee', 'moyenne', 'faible'];
export const rangGravite = (g) => { const i = ORDRE_GRAVITE.indexOf(g); return i < 0 ? ORDRE_GRAVITE.length : i; };

export const NIVEAUX_RISQUE = {
  critique: { libelle: 'Critique', couleur: COULEURS.sos },
  eleve: { libelle: 'Élevé', couleur: COULEURS.or },
  moyen: { libelle: 'Moyen', couleur: COULEURS.bleuVif },
  faible: { libelle: 'Faible', couleur: COULEURS.succes },
};

const dtf = new Intl.DateTimeFormat('fr-FR', { dateStyle: 'medium', timeStyle: 'short' });
const df = new Intl.DateTimeFormat('fr-FR', { dateStyle: 'medium' });
const rtf = new Intl.RelativeTimeFormat('fr', { numeric: 'auto' });

export const dateHeure = (v) => (v ? dtf.format(new Date(v)) : '—');
export const date = (v) => (v ? df.format(new Date(v)) : '—');

export function ilYa(v) {
  if (!v) return '—';
  const s = (new Date(v).getTime() - Date.now()) / 1000;
  const a = Math.abs(s);
  if (a < 60) return 'à l’instant';
  if (a < 3600) return rtf.format(Math.round(s / 60), 'minute');
  if (a < 86400) return rtf.format(Math.round(s / 3600), 'hour');
  return rtf.format(Math.round(s / 86400), 'day');
}

export const distance = (m) => (m == null ? '—' : m < 1000 ? `${m} m` : `${(m / 1000).toFixed(1).replace('.', ',')} km`);
export const duree = (min) => (min == null ? '—' : min < 60 ? `${Math.round(min)} min` : `${Math.floor(min / 60)} h ${String(Math.round(min % 60)).padStart(2, '0')}`);
export const pct = (v) => (v == null ? '—' : `${String(v).replace('.', ',')} %`);
export const nombre = (v) => (v == null ? '—' : new Intl.NumberFormat('fr-FR').format(v));

export const isoJour = (d) => {
  const x = new Date(d);
  return `${x.getFullYear()}-${String(x.getMonth() + 1).padStart(2, '0')}-${String(x.getDate()).padStart(2, '0')}`;
};
