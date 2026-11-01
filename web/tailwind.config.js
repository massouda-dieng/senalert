import { readFileSync } from 'node:fs';
import plugin from 'tailwindcss/plugin';

/** Système de design SenAlert. Toutes les couleurs viennent de design/couleurs.json, partagé avec Flutter. */
const J = JSON.parse(readFileSync(new URL('../design/couleurs.json', import.meta.url), 'utf8'));

const rgb = (hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16)).join(' ');
const rgba = (hex, a) => `rgba(${[1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16)).join(',')},${a})`;
const variables = (s) => ({
  '--c-surface': rgb(s.surface), '--c-surface-douce': rgb(s.douce), '--c-surface-subtile': rgb(s.subtile), '--c-bord': rgb(s.bord),
  '--c-texte': rgb(s.texte), '--c-texte-doux': rgb(s.texteDoux), '--c-texte-pale': rgb(s.textePale),
});

export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        marque: J.marque, // 800 = bleu marine (principal), 600 = bleu professionnel (secondaire)
        or: J.or, // vigilance : texte foncé dessus
        sos: J.sos, // urgence et SOS uniquement
        alerte: J.alerte,
        succes: J.succes, // réussite ; DEFAULT pour le texte et les boutons, vif pour les icônes et graphiques
        statut: J.statuts,
        gravite: J.gravites,
        // Surfaces et texte : variables CSS → modes clair et sombre
        surface: { DEFAULT: 'rgb(var(--c-surface) / <alpha-value>)', douce: 'rgb(var(--c-surface-douce) / <alpha-value>)', subtile: 'rgb(var(--c-surface-subtile) / <alpha-value>)', bord: 'rgb(var(--c-bord) / <alpha-value>)' },
        texte: { DEFAULT: 'rgb(var(--c-texte) / <alpha-value>)', doux: 'rgb(var(--c-texte-doux) / <alpha-value>)', pale: 'rgb(var(--c-texte-pale) / <alpha-value>)' },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'Segoe UI', 'sans-serif'],
        titre: ['"Plus Jakarta Sans"', 'Inter', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        carte: `0 1px 2px ${rgba(J.marque[800], 0.05)}, 0 4px 14px ${rgba(J.marque[800], 0.05)}`,
        flottant: `0 16px 48px ${rgba(J.marque[950], 0.22)}`,
      },
      backgroundImage: {
        drapeau: `linear-gradient(90deg,${J.marque[800]},${J.marque[600]} 62%,${J.marque[500]})`,
      },
      keyframes: {
        pulsation: { '0%': { boxShadow: `0 0 0 0 ${rgba(J.sos.DEFAULT, 0.5)}` }, '100%': { boxShadow: `0 0 0 30px ${rgba(J.sos.DEFAULT, 0)}` } },
        apparition: { from: { opacity: 0, transform: 'translateY(8px)' }, to: { opacity: 1, transform: 'none' } },
        zoomLent: { from: { transform: 'scale(1.06)' }, to: { transform: 'scale(1)' } },
      },
      animation: {
        pulsation: 'pulsation 1.8s ease-out infinite',
        apparition: 'apparition .3s ease-out',
        zoomLent: 'zoomLent 12s ease-out forwards',
      },
    },
  },
  plugins: [plugin(({ addBase }) => addBase({
    ':root': { ...variables(J.surfaces.clair), colorScheme: 'light' },
    '.dark': { ...variables(J.surfaces.sombre), colorScheme: 'dark' },
  }))],
};
