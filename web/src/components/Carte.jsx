import 'leaflet/dist/leaflet.css';
import 'leaflet.markercluster/dist/MarkerCluster.css';
import L from 'leaflet';
import 'leaflet.markercluster';
import { useEffect, useMemo } from 'react';
import { MapContainer, TileLayer, useMap, useMapEvents } from 'react-leaflet';

export const CENTRE_SENEGAL = [14.45, -14.9];

/** Icône ronde colorée (pas d'image externe). `sos` ajoute un halo rouge. */
export function icone(couleur, { sos = false, taille = 16 } = {}) {
  return L.divIcon({
    className: '',
    iconSize: [taille, taille],
    html: `<span style="display:block;width:${taille}px;height:${taille}px;border-radius:999px;background:${couleur};border:2.5px solid #fff;box-shadow:0 0 0 ${sos ? 6 : 1}px ${sos ? 'rgba(225,29,72,.28)' : 'rgba(7,19,48,.25)'},0 2px 6px rgba(7,19,48,.35)"></span>`,
  });
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
      const m = L.marker([p.lat, p.lng], { icon: icone(p.couleur, { sos: p.sos }), keyboard: true, title: p.titre || '' });
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
      <MapContainer center={centre} zoom={zoom} scrollWheelZoom className="h-full w-full" aria-label="Carte interactive">
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
