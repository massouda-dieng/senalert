/** Système de design SenAlert « Sénégal vibrant » — mêmes jetons que l'application Flutter (AppColors). */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        // Vert du drapeau (#00853F) : identité, navigation, actions principales
        marque: { 950: '#00210F', 900: '#003A1B', 800: '#005527', 700: '#006E33', 600: '#00853F', 500: '#16A152', 100: '#D3F0DF', 50: '#ECF8F1' },
        // Jaune du drapeau : accents, étoile, mises en avant
        or: { DEFAULT: '#FDEF42', vif: '#F5D90A', fonce: '#8A6D00', clair: '#FFF9D1' },
        // Rouge du drapeau : réservé au SOS et à l'urgence critique
        sos: { DEFAULT: '#E31B23', fonce: '#B5121A', clair: '#FDE3E4' },
        alerte: { DEFAULT: '#C2410C', clair: '#FFEDD5', vif: '#EA580C' },
        succes: { DEFAULT: '#047857', clair: '#D1FAE5' },
        surface: { DEFAULT: '#FFFFFF', douce: '#F8F7F1', bord: '#E7E4D8' },
        texte: { DEFAULT: '#10231A', doux: '#53645B', pale: '#8A978F' },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'Segoe UI', 'sans-serif'],
        titre: ['"Plus Jakarta Sans"', 'Inter', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        carte: '0 1px 2px rgba(16,35,26,.04), 0 6px 20px rgba(16,35,26,.06)',
        flottant: '0 16px 48px rgba(0,33,15,.22)',
      },
      backgroundImage: {
        drapeau: 'linear-gradient(90deg,#00853F 0 33.3%,#FDEF42 33.3% 66.6%,#E31B23 66.6% 100%)',
      },
      keyframes: {
        pulsation: { '0%': { boxShadow: '0 0 0 0 rgba(227,27,35,.5)' }, '100%': { boxShadow: '0 0 0 30px rgba(227,27,35,0)' } },
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
  plugins: [],
};
