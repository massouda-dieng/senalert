/**
 * Mise à jour automatique : chaque onglet compare sa version à celle du serveur (nom du fichier
 * compilé) et se recharge dès qu'une nouvelle version existe. La session est conservée.
 * Jamais pendant une saisie ou une fenêtre ouverte (SOS en cours, signalement, formulaire).
 */
const INTERVALLE = 30000;
const CLE = 'senalert.version-rechargee';

export const versionDepuisHtml = (html) => html.match(/assets\/index-[\w-]+\.js/)?.[0] ?? null;

export function occupe(doc = document) {
  if (doc.querySelector('[role=dialog]')) return true;
  return [...doc.querySelectorAll('input, textarea')].some((c) => !['checkbox', 'radio'].includes(c.type) && c.value);
}

export function surveillerMiseAJour() {
  const script = document.querySelector('script[type=module][src*="/assets/index-"]');
  const actuelle = script ? versionDepuisHtml(script.getAttribute('src')) : null;
  if (!actuelle) return;
  const verifier = async () => {
    if (document.visibilityState !== 'visible' || occupe()) return;
    try {
      const reponse = await fetch('/app/', { cache: 'no-store' });
      const serveur = reponse.ok ? versionDepuisHtml(await reponse.text()) : null;
      if (!serveur || serveur === actuelle || sessionStorage.getItem(CLE) === serveur) return;
      sessionStorage.setItem(CLE, serveur); // une seule tentative par version : jamais de boucle
      window.location.reload();
    } catch { /* hors connexion : nouvel essai plus tard */ }
  };
  setInterval(verifier, INTERVALLE);
  document.addEventListener('visibilitychange', verifier);
  window.addEventListener('focus', verifier);
}
