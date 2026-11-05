import { useCallback, useEffect, useRef, useState } from 'react';
import { api } from '../api/client';

/** Durée maximale d'un message vocal (le serveur refuse au-delà de 8 Mo). */
export const DUREE_MAX_S = 60;

const TYPES_ENREGISTREMENT = ['audio/webm;codecs=opus', 'audio/webm', 'audio/ogg;codecs=opus', 'audio/mp4'];

/** Extension de fichier attendue par le serveur pour un type MIME d'enregistrement. */
export function extensionAudio(type = '') {
  if (type.includes('webm')) return 'webm';
  if (type.includes('ogg')) return 'ogg';
  if (type.includes('mp4') || type.includes('aac') || type.includes('m4a')) return 'm4a';
  if (type.includes('wav')) return 'wav';
  return 'webm';
}

export const dicteePossible = () =>
  typeof window !== 'undefined' && Boolean(window.MediaRecorder && navigator.mediaDevices?.getUserMedia);

export const lecturePossible = () => typeof window !== 'undefined' && 'speechSynthesis' in window;

/** Texte lu à voix haute : sans puces ni symboles que la synthèse vocale prononcerait. */
export function texteAParler(texte = '') {
  return texte.replace(/[•*#_>]/g, ' ').replace(/\s+/g, ' ').trim();
}

/**
 * Dictée : enregistre la voix, l'envoie au serveur (Whisper) et renvoie le texte reconnu.
 * L'audio n'est ni conservé sur l'appareil ni enregistré par le serveur.
 */
export function useDictee({ surTexte, surErreur }) {
  const [etat, setEtat] = useState('repos'); // repos | enregistrement | transcription
  const [secondes, setSecondes] = useState(0);
  const enregistreur = useRef(null);
  const flux = useRef(null);
  const minuteur = useRef(null);
  const annule = useRef(false);

  const liberer = useCallback(() => {
    clearInterval(minuteur.current);
    flux.current?.getTracks().forEach((piste) => piste.stop());
    flux.current = null;
  }, []);

  const arreter = useCallback(() => {
    if (enregistreur.current?.state === 'recording') enregistreur.current.stop();
  }, []);

  const annuler = useCallback(() => { annule.current = true; arreter(); }, [arreter]);

  const transcrire = useCallback(async (blob) => {
    if (annule.current || blob.size === 0) { setEtat('repos'); return; }
    setEtat('transcription');
    try {
      const corps = new FormData();
      corps.append('audio', blob, `message.${extensionAudio(blob.type)}`);
      const r = await api('/analyse/assistant/transcrire/', { methode: 'POST', corps });
      surTexte(r.texte);
    } catch (e) {
      surErreur(e.detail || 'La dictée vocale a échoué. Écrivez votre question.');
    } finally { setEtat('repos'); }
  }, [surTexte, surErreur]);

  const demarrer = useCallback(async () => {
    if (etat !== 'repos') return;
    try {
      flux.current = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true } });
    } catch (e) {
      surErreur(e?.name === 'NotAllowedError'
        ? 'Micro refusé. Autorisez le micro pour ce site dans le navigateur, puis réessayez.'
        : 'Aucun micro disponible sur cet appareil.');
      return;
    }
    const type = TYPES_ENREGISTREMENT.find((t) => window.MediaRecorder.isTypeSupported?.(t));
    const rec = new window.MediaRecorder(flux.current, type ? { mimeType: type } : undefined);
    const morceaux = [];
    annule.current = false;
    rec.ondataavailable = (ev) => { if (ev.data.size) morceaux.push(ev.data); };
    rec.onstop = () => { liberer(); transcrire(new Blob(morceaux, { type: rec.mimeType || type || 'audio/webm' })); };
    enregistreur.current = rec;
    rec.start();
    setSecondes(0);
    setEtat('enregistrement');
    const debut = Date.now();
    minuteur.current = setInterval(() => {
      const s = Math.floor((Date.now() - debut) / 1000);
      setSecondes(s);
      if (s >= DUREE_MAX_S) arreter();
    }, 250);
  }, [etat, liberer, transcrire, arreter, surErreur]);

  // Quitter l'écran pendant un enregistrement coupe le micro sans rien envoyer.
  useEffect(() => () => { annule.current = true; if (enregistreur.current?.state === 'recording') enregistreur.current.stop(); liberer(); }, [liberer]);

  return { etat, secondes, demarrer, arreter, annuler };
}

/** Lecture à voix haute (synthèse vocale du navigateur, en français). Un seul message lu à la fois. */
export function useLecture() {
  const [enCours, setEnCours] = useState(null);

  const arreter = useCallback(() => { if (lecturePossible()) window.speechSynthesis.cancel(); setEnCours(null); }, []);

  const lire = useCallback((id, texte) => {
    if (!lecturePossible()) return;
    window.speechSynthesis.cancel();
    if (enCours === id) { setEnCours(null); return; }
    const phrase = new window.SpeechSynthesisUtterance(texteAParler(texte));
    phrase.lang = 'fr-FR';
    const voix = window.speechSynthesis.getVoices().find((v) => v.lang?.toLowerCase().startsWith('fr'));
    if (voix) phrase.voice = voix;
    phrase.onend = () => setEnCours((c) => (c === id ? null : c));
    phrase.onerror = phrase.onend;
    setEnCours(id);
    window.speechSynthesis.speak(phrase);
  }, [enCours]);

  useEffect(() => arreter, [arreter]);
  return { enCours, lire, arreter };
}
