/**
 * Client HTTP de SenAlert.
 *  - jeton d'accès en mémoire, jeton de rafraîchissement en sessionStorage (fermé avec l'onglet) ;
 *  - renouvellement automatique sur 401 puis une seule nouvelle tentative ;
 *  - erreurs normalisées { status, detail, champs } en français ;
 *  - nouvelle tentative automatique uniquement pour les lectures (GET) en cas de coupure réseau.
 */
const BASE = '/api';
const CLE_REFRESH = 'senalert.refresh';

let accessToken = null;
let refreshEnCours = null;
const ecouteurs = new Set();

export class ErreurApi extends Error {
  constructor(status, detail, champs = null, code = null) {
    super(detail);
    this.status = status;
    this.detail = detail;
    this.champs = champs;
    this.code = code;
  }
}

function lireRefresh() {
  try { return sessionStorage.getItem(CLE_REFRESH); } catch { return null; }
}

export function enregistrerJetons({ access, refresh }) {
  accessToken = access || null;
  try {
    if (refresh) sessionStorage.setItem(CLE_REFRESH, refresh);
  } catch { /* stockage indisponible : la session ne survivra pas au rechargement */ }
}

export function effacerJetons() {
  accessToken = null;
  try { sessionStorage.removeItem(CLE_REFRESH); } catch { /* rien */ }
}

export const aUneSession = () => Boolean(accessToken || lireRefresh());
export const refreshActuel = lireRefresh;

/** Abonnement à l'expiration de session (déconnexion forcée). */
export function surSessionExpiree(fn) {
  ecouteurs.add(fn);
  return () => ecouteurs.delete(fn);
}

async function rafraichir() {
  const refresh = lireRefresh();
  if (!refresh) return false;
  if (!refreshEnCours) {
    refreshEnCours = fetch(`${BASE}/auth/jeton/rafraichir/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh }),
    })
      .then(async (r) => {
        if (!r.ok) return false;
        enregistrerJetons(await r.json());
        return true;
      })
      .catch(() => false)
      .finally(() => { setTimeout(() => { refreshEnCours = null; }, 0); });
  }
  return refreshEnCours;
}

const attendre = (ms) => new Promise((res) => setTimeout(res, ms));

function messageReseau() {
  return navigator.onLine === false
    ? 'Vous êtes hors connexion. Vérifiez votre réseau puis réessayez.'
    : 'Le serveur SenAlert est injoignable. Réessayez dans un instant.';
}

export async function api(chemin, { methode = 'GET', corps, params, brut = false, signal, auth = true } = {}) {
  const url = new URL(`${BASE}${chemin}`, window.location.origin);
  if (params) {
    Object.entries(params).forEach(([k, v]) => {
      if (v === undefined || v === null || v === '') return;
      if (Array.isArray(v)) v.forEach((x) => url.searchParams.append(k, x));
      else url.searchParams.set(k, v);
    });
  }
  const estFormulaire = corps instanceof FormData;

  const executer = async () => {
    const headers = {};
    if (!estFormulaire && corps !== undefined) headers['Content-Type'] = 'application/json';
    if (auth && accessToken) headers.Authorization = `Bearer ${accessToken}`;
    return fetch(url, {
      method: methode,
      headers,
      body: corps === undefined ? undefined : estFormulaire ? corps : JSON.stringify(corps),
      signal,
    });
  };

  let reponse;
  for (let essai = 0; ; essai += 1) {
    try {
      if (auth && !accessToken && lireRefresh()) await rafraichir();
      reponse = await executer();
      break;
    } catch (e) {
      if (e.name === 'AbortError') throw e;
      if (methode === 'GET' && essai < 2) { await attendre(800 * (essai + 1)); continue; }
      throw new ErreurApi(0, messageReseau(), null, 'reseau');
    }
  }

  if (reponse.status === 401 && auth && lireRefresh()) {
    accessToken = null;
    if (await rafraichir()) reponse = await executer();
    if (reponse.status === 401) {
      effacerJetons();
      ecouteurs.forEach((fn) => fn());
    }
  }

  if (brut && reponse.ok) return reponse;
  if (reponse.status === 204) return null;
  const type = reponse.headers.get('content-type') || '';
  const donnees = type.includes('application/json') ? await reponse.json().catch(() => null) : null;
  if (!reponse.ok) {
    const detail = donnees?.detail || (reponse.status >= 500
      ? 'Erreur du serveur. Réessayez plus tard.'
      : `Requête refusée (${reponse.status}).`);
    throw new ErreurApi(reponse.status, detail, donnees?.champs || null, donnees?.code || null);
  }
  return donnees;
}

/** Télécharge un fichier protégé (export, photo) avec le jeton courant. */
export async function telecharger(chemin, params, nomParDefaut) {
  const r = await api(chemin, { params, brut: true });
  const blob = await r.blob();
  const dispo = r.headers.get('content-disposition') || '';
  const nom = /filename="([^"]+)"/.exec(dispo)?.[1] || nomParDefaut;
  const lien = document.createElement('a');
  lien.href = URL.createObjectURL(blob);
  lien.download = nom;
  lien.click();
  setTimeout(() => URL.revokeObjectURL(lien.href), 2000);
}

export async function urlObjetProtege(chemin) {
  const r = await api(chemin.replace(/^\/api/, ''), { brut: true });
  return URL.createObjectURL(await r.blob());
}

export const nouvelleCle = () => (crypto.randomUUID ? crypto.randomUUID()
  : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  }));
