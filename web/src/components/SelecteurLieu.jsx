import 'leaflet/dist/leaflet.css';
import { Crosshair, MapPin, Minus, Plus, Search } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { Circle, MapContainer, TileLayer, useMap, useMapEvents } from 'react-leaflet';
import { api } from '../api/client';
import { lirePosition } from './BoutonSOS';
import { BORNES_SENEGAL } from './Carte';
import { Bandeau, Bouton } from './ui';

// Sans position connue, la carte s'ouvre sur l'agglomération de Dakar (lisible), pas sur tout le pays.
const DAKAR = [14.72, -17.42];

/** Recherche d'une adresse, d'un quartier ou d'une ville (OpenStreetMap via le serveur). */
function RechercheLieu({ onLieu }) {
  const [q, setQ] = useState('');
  const [resultats, setResultats] = useState(null);
  const [erreur, setErreur] = useState(null);
  const [enCours, setEnCours] = useState(false);
  const chercher = async (e) => {
    e.preventDefault();
    if (q.trim().length < 3) return;
    setEnCours(true); setErreur(null);
    try { setResultats((await api(`/geocodage/?q=${encodeURIComponent(q.trim())}`)).resultats); } catch (x) { setErreur(x.detail); setResultats(null); } finally { setEnCours(false); }
  };
  return (
    <div>
      <form onSubmit={chercher} className="flex gap-2">
        <input className="champ" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Rechercher une adresse, un quartier, une ville…" aria-label="Rechercher un lieu" />
        <Bouton type="submit" variante="secondaire" icone={Search} chargement={enCours}>Rechercher</Bouton>
      </form>
      {erreur && <p className="mt-2 text-sm text-alerte">{erreur} Touchez la carte à l’endroit de l’incident.</p>}
      {resultats && !resultats.length && <p className="mt-2 text-sm text-texte-doux">Aucun lieu trouvé : essayez un quartier ou une ville.</p>}
      {resultats?.length > 0 && (
        <ul className="mt-2 divide-y divide-surface-bord rounded-xl border border-surface-bord text-sm">
          {resultats.slice(0, 5).map((r) => (
            <li key={`${r.latitude},${r.longitude}`}>
              <button type="button" className="flex w-full items-start gap-2 px-3 py-2 text-left hover:bg-surface-douce" onClick={() => { onLieu(r.latitude, r.longitude); setResultats(null); setQ(r.nom.split(',')[0]); }}>
                <MapPin className="mt-0.5 h-4 w-4 shrink-0 text-marque-700" aria-hidden /> <span className="line-clamp-2">{r.nom}</span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

/** Événements de la carte : le lieu est toujours le centre ; un clic recentre la carte sur le point touché. */
function Centre({ cible, onCentre }) {
  const map = useMap();
  useEffect(() => { if (cible) map.flyTo([cible.lat, cible.lng], cible.zoom ?? Math.max(map.getZoom(), 16), { duration: 0.6 }); }, [map, cible]);
  useMapEvents({
    dragend: () => { const c = map.getCenter(); onCentre(c.lat, c.lng); },
    click: (e) => { map.panTo(e.latlng); onCentre(e.latlng.lat, e.latlng.lng); },
  });
  return null;
}

function Zoom() {
  const map = useMap();
  const bouton = 'grid h-9 w-9 place-items-center rounded-lg bg-surface text-marque-700 shadow-flottant hover:bg-surface-douce';
  return (
    <div className="absolute right-3 top-3 z-[500] flex flex-col gap-1.5">
      <button type="button" className={bouton} onClick={() => map.zoomIn()} aria-label="Zoomer"><Plus className="h-4 w-4" /></button>
      <button type="button" className={bouton} onClick={() => map.zoomOut()} aria-label="Dézoomer"><Minus className="h-4 w-4" /></button>
    </div>
  );
}

/**
 * Choix du lieu d'un incident, pensé pour un débutant : le repère rouge reste au centre et on fait glisser
 * la carte dessous. « Ma position » à l'ouverture (si autorisée), recherche d'adresse, clic sur la carte.
 * Si la localisation est refusée, la recherche et la carte restent utilisables.
 */
export default function SelecteurLieu({ lat, lng, precision, onLieu }) {
  const [gps, setGps] = useState(null);
  const [cible, setCible] = useState(null);
  const tente = useRef(false);
  const aPosition = lat != null;

  const allerA = (la, ln, prec = null, zoom) => { setCible({ lat: la, lng: ln, zoom, n: Date.now() }); onLieu(la, ln, prec); };
  const localiser = async () => {
    setGps({ enCours: true });
    const p = await lirePosition({ delai: 15000 });
    setGps(p);
    if (p.lat != null) allerA(p.lat, p.lng, Math.round(p.precision), 17);
  };
  // Première ouverture de l'étape : on tente directement la position de l'appareil.
  useEffect(() => { if (!aPosition && !tente.current) { tente.current = true; localiser(); } }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div className="space-y-3">
      <RechercheLieu onLieu={(la, ln) => allerA(la, ln, null, 17)} />
      <div className="relative overflow-hidden rounded-2xl border border-surface-bord" style={{ height: 380 }}>
        <MapContainer center={aPosition ? [lat, lng] : DAKAR} zoom={aPosition ? 16 : 12} minZoom={6} maxBounds={BORNES_SENEGAL}
          zoomControl={false} scrollWheelZoom className="h-full w-full" aria-label="Carte : faites glisser pour placer le repère sur le lieu">
          <TileLayer attribution='Fond &copy; Esri, HERE, Garmin, &copy; contributeurs <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
            url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}" maxZoom={19} />
          {aPosition && precision > 0 && <Circle center={[lat, lng]} radius={Math.min(precision, 1000)} pathOptions={{ color: '#2563eb', weight: 1, fillOpacity: 0.08 }} />}
          <Centre cible={cible} onCentre={(la, ln) => onLieu(la, ln, null)} />
          <Zoom />
        </MapContainer>
        {/* Repère fixe : sa pointe marque exactement le centre de la carte. */}
        <div className="pointer-events-none absolute left-1/2 top-1/2 z-[600] -translate-x-1/2 -translate-y-full" aria-hidden>
          <svg width="40" height="52" viewBox="0 0 36 47" style={{ filter: 'drop-shadow(0 3px 4px rgba(7,19,48,.4))' }}>
            <path d="M18 1C8.6 1 1 8.6 1 18c0 12.4 17 28 17 28s17-15.6 17-28C35 8.6 27.4 1 18 1z" fill={aPosition ? '#dc2626' : '#64748b'} stroke="#fff" strokeWidth="2" />
            <circle cx="18" cy="18" r="6" fill="#fff" />
          </svg>
        </div>
        {!aPosition && (
          <p className="pointer-events-none absolute left-1/2 top-4 z-[600] -translate-x-1/2 rounded-full bg-marque-900/85 px-3.5 py-1.5 text-xs font-semibold text-white">
            Faites glisser la carte pour placer le repère sur le lieu
          </p>
        )}
        <div className="absolute bottom-4 left-3 z-[600]">
          <Bouton icone={Crosshair} chargement={gps?.enCours} onClick={localiser} className="shadow-flottant">Ma position</Bouton>
        </div>
      </div>
      {gps?.erreur && <Bandeau type="alerte">{gps.erreur} Recherchez l’adresse ou faites glisser la carte jusqu’au lieu.</Bandeau>}
      <p className={`flex items-center gap-1.5 text-sm ${aPosition ? 'font-semibold text-succes' : 'text-texte-doux'}`}>
        <MapPin className="h-4 w-4 shrink-0" aria-hidden />
        {!aPosition ? 'Aucun lieu placé pour l’instant.'
          : precision ? `Votre position GPS (précision ± ${precision} m). Ajustez la carte si l’incident est un peu plus loin.`
          : `Lieu placé sur la carte (${lat.toFixed(5)}, ${lng.toFixed(5)}).`}
      </p>
    </div>
  );
}
