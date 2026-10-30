export const STATUTS = {
  nouveau: { libelle: 'Nouveau', classe: 'bg-nuit-50 text-nuit-700 ring-nuit-600/20', point: '#1D4ED8' },
  affecte: { libelle: 'Affecté', classe: 'bg-violet-50 text-violet-700 ring-violet-600/20', point: '#7C3AED' },
  accepte: { libelle: 'Pris en charge', classe: 'bg-sky-50 text-sky-700 ring-sky-600/20', point: '#0284C7' },
  en_cours: { libelle: 'En cours', classe: 'bg-alerte-clair text-amber-800 ring-amber-600/20', point: '#D97706' },
  resolu: { libelle: 'Résolu', classe: 'bg-succes-clair text-emerald-800 ring-emerald-600/20', point: '#059669' },
  refuse: { libelle: 'Rejeté', classe: 'bg-slate-100 text-slate-600 ring-slate-500/20', point: '#64748B' },
  annule: { libelle: 'Annulé', classe: 'bg-slate-100 text-slate-600 ring-slate-500/20', point: '#94A3B8' },
};

export const GRAVITES = {
  faible: { libelle: 'Faible', classe: 'text-slate-600 bg-slate-100' },
  moyenne: { libelle: 'Moyenne', classe: 'text-nuit-700 bg-nuit-50' },
  elevee: { libelle: 'Élevée', classe: 'text-amber-800 bg-alerte-clair' },
  critique: { libelle: 'Critique', classe: 'text-white bg-sos' },
};

export const NIVEAUX_RISQUE = {
  critique: { libelle: 'Critique', couleur: '#E11D48' },
  eleve: { libelle: 'Élevé', couleur: '#F97316' },
  moyen: { libelle: 'Moyen', couleur: '#D97706' },
  faible: { libelle: 'Faible', couleur: '#059669' },
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
