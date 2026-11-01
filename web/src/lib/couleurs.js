import J from '../../../design/couleurs.json';

/**
 * Couleurs pour ce que Tailwind ne couvre pas (cartes Leaflet, graphiques, icônes dessinées).
 * Source unique : design/couleurs.json. Dans le JSX, préférez les classes Tailwind (bg-marque-800, text-sos…).
 *
 * Règles d'usage : rouge = urgence et SOS uniquement ; orange = vigilance ; vert = réussite ;
 * sur fond coloré en petit texte, utiliser les variantes foncées (sosFonce, succesFonce) : contraste AA.
 */
export const COULEURS = {
  marine: J.marque[800],
  bleu: J.marque[600],
  bleuVif: J.marque[500],
  sos: J.sos.DEFAULT,
  sosFonce: J.sos.fonce,
  or: J.or.DEFAULT,
  succes: J.succes.vif,
  succesFonce: J.succes.DEFAULT,
  gris: J.neutre.gris,
  grisClair: J.neutre.grisClair,
  blanc: J.surfaces.clair.surface,
  fondSombre: J.surfaces.sombre.douce,
  statuts: J.statuts,
  gravites: J.gravites,
  services: J.services,
  graphiques: J.graphiques,
};
