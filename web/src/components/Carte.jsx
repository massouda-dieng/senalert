import 'leaflet/dist/leaflet.css';
import 'leaflet.markercluster/dist/MarkerCluster.css';
import L from 'leaflet';
import 'leaflet.markercluster';
import { useEffect, useMemo } from 'react';
import { COULEURS } from '../lib/couleurs';
import { MapContainer, TileLayer, useMap, useMapEvents } from 'react-leaflet';

export const CENTRE_SENEGAL = [14.45, -14.9];
/** Cadre de la carte nationale : le Sénégal et ses frontières, jamais le planisphère répété. */
export const BORNES_SENEGAL = [[9, -22], [20, -7]];

// Pictogrammes des épingles (tracés Lucide, licence ISC), par catégorie d'incident, service ou type de point.
const FLAMME = '<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14-.22-4.05 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.15.43-2.29 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>';
const CROIX = '<path d="M11 2a2 2 0 0 0-2 2v5H4a2 2 0 0 0-2 2v2c0 1.1.9 2 2 2h5v5c0 1.1.9 2 2 2h2a2 2 0 0 0 2-2v-5h5a2 2 0 0 0 2-2v-2a2 2 0 0 0-2-2h-5V4a2 2 0 0 0-2-2h-2z"/>';
const BOUCLIER = '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/>';
const ECLAIR = '<path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/>';
const GOUTTE = '<path d="M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z"/>';
const PICTOS = {
  incendie: FLAMME, pompiers: FLAMME,
  accident: '<path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><path d="M9 17h6"/><circle cx="17" cy="17" r="2"/>',
  inondation: GOUTTE, onas: GOUTTE,
  insecurite: `${BOUCLIER}<path d="M12 8v4"/><path d="M12 16h.01"/>`, police: BOUCLIER,
  agression: '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
  electricite: ECLAIR, senelec: ECLAIR,
  urgence_medicale: CROIX, sante: CROIX, hopital: CROIX, clinique: CROIX, pharmacie: CROIX,
  sos: '<circle cx="12" cy="12" r="9"/><path d="M12 7v6"/><path d="M12 17h.01"/>',
  structure: '<rect width="16" height="20" x="4" y="2" rx="2"/><path d="M9 22v-4h6v4"/><path d="M8 6h.01M12 6h.01M16 6h.01M8 10h.01M12 10h.01M16 10h.01M8 14h.01M12 14h.01M16 14h.01"/>',
};

/**
 * Épingle colorée avec le pictogramme du type (catégorie d'incident, service, « sos »…), sans image externe.
 * La pointe de l'épingle marque le lieu exact.
 */
export function icone(couleur, { sos = false, taille = 16, type } = {}) {
  const l = Math.round(22 + taille * 0.7 + (sos ? 4 : 0));
  const h = Math.round(l * 1.3);
  const picto = PICTOS[sos ? 'sos' : type] || '<circle cx="12" cy="12" r="3.5" fill="#fff"/>';
  return L.divIcon({
    className: '',
    iconSize: [l, h],
    iconAnchor: [l / 2, h],
    popupAnchor: [0, -h + 6],
    html: `<svg width="${l}" height="${h}" viewBox="0 0 36 47" style="filter:drop-shadow(0 2px 3px rgba(7,19,48,.35))">`
      + `<path d="M18 1C8.6 1 1 8.6 1 18c0 12.4 17 28 17 28s17-15.6 17-28C35 8.6 27.4 1 18 1z" fill="${couleur}" stroke="#fff" stroke-width="2"/>`
      + `<g transform="translate(8 8) scale(.84)" fill="none" stroke="#fff" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">${picto}</g></svg>`,
  });
}

/** Marqueur de l'agent en route : pastille bleu nuit avec un camion, distincte des statuts. */
export const ICONE_AGENT = L.divIcon({
  className: '',
  iconSize: [30, 30],
  html: `<span style="display:grid;place-items:center;width:30px;height:30px;border-radius:10px;background:${COULEURS.bleu};border:2.5px solid #fff;box-shadow:0 2px 8px rgba(7,19,48,.45)">`
    + '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">'
    + '<path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2"/><path d="M15 18H9"/><path d="M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.62L18.3 9.38a1 1 0 0 0-.78-.38H14"/>'
    + '<circle cx="17" cy="18" r="2"/><circle cx="7" cy="18" r="2"/></svg></span>',
});

/** Position de l'utilisateur : point bleu pulsé avec l'étiquette « Vous êtes ici ». */
export const ICONE_MOI = L.divIcon({
  className: '',
  iconSize: [20, 20],
  iconAnchor: [10, 10],
  html: `<span class="sa-moi"><span class="sa-moi-halo" style="background:${COULEURS.bleuVif}"></span>`
    + `<span class="sa-moi-point" style="background:${COULEURS.bleu}"></span><span class="sa-moi-etiquette">Vous êtes ici</span></span>`,
});

/** Distance à vol d'oiseau en kilomètres (formule de haversine). */
export function distanceKm(a, b) {
  const rad = (d) => (d * Math.PI) / 180;
  const h = Math.sin(rad(b.lat - a.lat) / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(rad(b.lng - a.lng) / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

/**
 * Couche de marqueurs regroupés.
 * points : [{ id, lat, lng, couleur, sos, popup (HTML échappé), onClick }]
 */
function CoucheMarqueurs({ points, regrouper }) {
  const map = useMap();
  useEffect(() => {
    const groupe = regrouper ? L.markerClusterGroup({ showCoverageOnHover: false, maxClusterRadius: 45 }) : L.layerGroup();
    points.forEach((p) => {
      const m = L.marker([p.lat, p.lng], { icon: p.agent ? ICONE_AGENT : p.moi ? ICONE_MOI : icone(p.couleur, { sos: p.sos, type: p.type, taille: p.taille }), keyboard: true, title: p.titre || '', zIndexOffset: p.agent ? 500 : 0 });
      if (p.popup) m.bindPopup(p.popup);
      if (p.onClick) m.on('click', () => p.onClick());
      groupe.addLayer(m);
    });
    groupe.addTo(map);
    return () => { map.removeLayer(groupe); };
  }, [map, points, regrouper]);
  return null;
}

function Cadrage({ points, cadrer }) {
  const map = useMap();
  useEffect(() => {
    if (!cadrer || !points.length) return;
    const b = L.latLngBounds(points.map((p) => [p.lat, p.lng]));
    map.fitBounds(b.pad(0.2), { maxZoom: 13 });
  }, [map, points, cadrer]);
  return null;
}

function Clic({ onClic }) {
  useMapEvents({ click: (e) => onClic?.(e.latlng) });
  return null;
}

export const echapper = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

export default function CarteSenAlert({ points = [], centre = CENTRE_SENEGAL, zoom = 7, hauteur = 480, regrouper = true, cadrer = false, onClic, children, className = '' }) {
  const pts = useMemo(() => points.filter((p) => p.lat != null && p.lng != null), [points]);
  return (
    <div className={`relative overflow-hidden rounded-2xl border border-surface-bord ${className}`} style={{ height: hauteur }}>
      <MapContainer center={centre} zoom={zoom} minZoom={5} scrollWheelZoom={false} className="h-full w-full" aria-label="Carte interactive">
        {/* Plan Esri : les tuiles tile.openstreetmap.org renvoient 403 sans en-tête Referer (Referrer-Policy same-origin). */}
        <TileLayer attribution='Fond &copy; Esri, HERE, Garmin, &copy; contributeurs <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}" maxZoom={19} />
        <CoucheMarqueurs points={pts} regrouper={regrouper} />
        <Cadrage points={pts} cadrer={cadrer} />
        {onClic && <Clic onClic={onClic} />}
        {children}
      </MapContainer>
    </div>
  );
}

export function Legende({ elements }) {
  return (
    <div className="flex flex-wrap gap-x-4 gap-y-1.5 text-xs text-texte-doux">
      {elements.map((e) => (
        <span key={e.libelle} className="inline-flex items-center gap-1.5">
          <span className="h-2.5 w-2.5 rounded-full ring-2 ring-white" style={{ background: e.couleur }} aria-hidden />{e.libelle}
        </span>
      ))}
    </div>
  );
}
