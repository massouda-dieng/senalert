import credits from './credits-photos.json';

/** Photos d'illustration (Wikimedia Commons, licences libres). Elles ne représentent aucun incident réel. */
export const PHOTOS = Object.fromEntries(credits.map((c) => [c.fichier.replace('.jpg', ''), { ...c, url: `${import.meta.env.BASE_URL}images/${c.fichier}` }]));

export const CREDITS = credits;

export const creditCourt = (p) => `Photo : ${p.auteur} — ${p.licence}`;
