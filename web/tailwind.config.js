/** Système de design SenAlert — mêmes jetons que l'application Flutter (AppColors). */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        nuit: { 950: '#050D22', 900: '#071330', 800: '#0B1F4D', 700: '#12307A', 600: '#1D4ED8', 50: '#EEF3FF' },
        sos: { DEFAULT: '#E11D48', fonce: '#BE123C', clair: '#FFE4E9' },
        alerte: { DEFAULT: '#D97706', clair: '#FEF3C7', vif: '#F97316' },
        succes: { DEFAULT: '#059669', clair: '#D1FAE5' },
        surface: { DEFAULT: '#FFFFFF', douce: '#F3F6FC', bord: '#E1E7F2' },
        texte: { DEFAULT: '#0B1630', doux: '#5B6680', pale: '#8A94AB' },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'Segoe UI', 'sans-serif'],
        titre: ['"Plus Jakarta Sans"', 'Inter', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        carte: '0 1px 2px rgba(11,22,48,.04), 0 4px 16px rgba(11,22,48,.06)',
        flottant: '0 12px 40px rgba(7,19,48,.18)',
      },
      keyframes: {
        pulsation: { '0%': { boxShadow: '0 0 0 0 rgba(225,29,72,.45)' }, '100%': { boxShadow: '0 0 0 28px rgba(225,29,72,0)' } },
        apparition: { from: { opacity: 0, transform: 'translateY(6px)' }, to: { opacity: 1, transform: 'none' } },
      },
      animation: { pulsation: 'pulsation 1.8s ease-out infinite', apparition: 'apparition .25s ease-out' },
    },
  },
  plugins: [],
};
