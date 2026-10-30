/** Thème clair / sombre / système, mémorisé sur l'appareil. */
const CLE = 'senalert.theme';
const media = () => window.matchMedia?.('(prefers-color-scheme: dark)');

export function themeChoisi() {
  try { return localStorage.getItem(CLE) || 'systeme'; } catch { return 'systeme'; }
}

export function appliquerTheme(choix = themeChoisi()) {
  const sombre = choix === 'sombre' || (choix === 'systeme' && media()?.matches);
  document.documentElement.classList.toggle('dark', Boolean(sombre));
  document.querySelector('meta[name=theme-color]')?.setAttribute('content', sombre ? '#0B110E' : '#00853F');
  return sombre;
}

export function choisirTheme(choix) {
  try { localStorage.setItem(CLE, choix); } catch { /* rien */ }
  return appliquerTheme(choix);
}

export function suivreSysteme() {
  media()?.addEventListener?.('change', () => { if (themeChoisi() === 'systeme') appliquerTheme('systeme'); });
}
