/* Service worker SenAlert : application disponible hors connexion pour l'essentiel.
 * - pages /app/ : réseau d'abord, repli sur la dernière version en cache ;
 * - fichiers /static/ (versionnés) : cache d'abord ;
 * - API : jamais en cache ici (les fiches de secours et la configuration sont
 *   mémorisées par l'application elle-même). Aucune donnée personnelle n'est stockée. */
const VERSION = 'senalert-v3.2';
const COQUILLE = '/app/';

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll([COQUILLE])).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((cles) => Promise.all(cles.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  const url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== self.location.origin || url.pathname.startsWith('/api/')) return;

  if (req.mode === 'navigate' && url.pathname.startsWith('/app')) {
    e.respondWith(fetch(req).then((r) => {
      const copie = r.clone();
      caches.open(VERSION).then((c) => c.put(COQUILLE, copie));
      return r;
    }).catch(() => caches.match(COQUILLE)));
    return;
  }
  if (url.pathname.startsWith('/static/')) {
    e.respondWith(caches.match(req).then((enCache) => enCache || fetch(req).then((r) => {
      if (r.ok) { const copie = r.clone(); caches.open(VERSION).then((c) => c.put(req, copie)); }
      return r;
    })));
  }
});
