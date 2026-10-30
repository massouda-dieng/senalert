import { useEffect, useState } from 'react';

let evenementDiffere = null;
const abonnes = new Set();
window.addEventListener?.('beforeinstallprompt', (e) => {
  e.preventDefault();
  evenementDiffere = e;
  abonnes.forEach((f) => f(true));
});
window.addEventListener?.('appinstalled', () => { evenementDiffere = null; abonnes.forEach((f) => f(false)); });

const estIOS = () => /iphone|ipad|ipod/i.test(navigator.userAgent);
export const estInstallee = () => window.matchMedia?.('(display-mode: standalone)').matches || window.navigator.standalone === true;

/** Installation de la PWA : invite native (Android, Chrome, Edge) ou consigne iOS (Partager → Sur l'écran d'accueil). */
export function useInstallation() {
  const [disponible, setDisponible] = useState(Boolean(evenementDiffere));
  useEffect(() => { abonnes.add(setDisponible); return () => abonnes.delete(setDisponible); }, []);
  return {
    possible: !estInstallee() && (disponible || estIOS()),
    ios: estIOS() && !disponible,
    installer: async () => {
      if (!evenementDiffere) return false;
      evenementDiffere.prompt();
      const { outcome } = await evenementDiffere.userChoice;
      evenementDiffere = null;
      setDisponible(false);
      return outcome === 'accepted';
    },
  };
}
