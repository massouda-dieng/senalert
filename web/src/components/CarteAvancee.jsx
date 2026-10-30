import 'leaflet/dist/leaflet.css';
import 'leaflet.markercluster/dist/MarkerCluster.css';
import clsx from 'clsx';
import L from 'leaflet';
import 'leaflet.heat';
import 'leaflet.markercluster';
import { Layers, LocateFixed, MapPin, Navigation, Search, X } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { Circle, MapContainer, TileLayer, Tooltip as InfoBulle, useMap } from 'react-leaflet';
import { useSearchParams } from 'react-router-dom';
import { api } from '../api/client';
import { useRessource } from '../api/hooks';
import { useConfig } from '../lib/config';
import { NIVEAUX_RISQUE, STATUTS, dateHeure } from '../lib/format';
import { BORNES_SENEGAL, CENTRE_SENEGAL, echapper, icone } from './Carte';
import { IndicateurSynchro, Selecteur } from './ui';

const FONDS = {
  plan: { libelle: 'Plan', url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}', attribution: 'Fond &copy; Esri, HERE, Garmin, &copy; contributeurs OpenStreetMap' },
  clair: { libelle: 'Clair', url: 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}', attribution: 'Fond &copy; Esri, HERE, Garmin, &copy; contributeurs OpenStreetMap' },
  satellite: { libelle: 'Satellite', url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', attribution: 'Imagerie &copy; Esri, Maxar, Earthstar Geographics' },
};

const COULEUR_ALERTE = { danger: '#E31B23', vigilance: '#F5D90A', info: '#006E33' };

function Marqueurs({ points, regrouper = true }) {
  const map = useMap();
  useEffect(() => {
    const groupe = regrouper ? L.markerClusterGroup({ showCoverageOnHover: false, maxClusterRadius: 45 }) : L.layerGroup();
    points.forEach((p) => {
      const m = L.marker([p.lat, p.lng], { icon: icone(p.couleur, { sos: p.sos, taille: p.taille || 16 }), title: p.titre || '' });
      if (p.popup) m.bindPopup(p.popup);
      groupe.addLayer(m);
    });
    groupe.addTo(map);
    return () => { map.removeLayer(groupe); };
  }, [map, points, regrouper]);
  return null;
}

function CoucheChaleur({ points }) {
  const map = useMap();
  useEffect(() => {
    if (!points.length) return undefined;
    const couche = L.heatLayer(points.map((p) => [p.lat, p.lng, p.poids || 0.6]), {
      radius: 38, blur: 26, maxZoom: 11, max: 0.5, minOpacity: 0.4, gradient: { 0.2: '#16A152', 0.5: '#F5D90A', 0.8: '#EA580C', 1: '#E31B23' },
    });
    couche.addTo(map);
    return () => { map.removeLayer(couche); };
  }, [map, points]);
  return null;
}

function Pilote({ cible }) {
  const map = useMap();
  useEffect(() => { if (cible) map.flyTo([cible.lat, cible.lng], cible.zoom || 15, { duration: 0.8 }); }, [map, cible]);
  return null;
}

function RechercheAdresse({ onChoix }) {
  const [q, setQ] = useState('');
  const [resultats, setResultats] = useState([]);
  const [etat, setEtat] = useState(null);
  const chercher = async (e) => {
    e.preventDefault();
    if (q.trim().length < 3) return;
    setEtat('chargement');
    try {
      const r = await api('/geocodage/', { params: { q: q.trim() } });
      setResultats(r.resultats);
      setEtat(r.resultats.length ? null : 'vide');
    } catch (err) { setEtat(err.detail); setResultats([]); }
  };
  return (
    <div className="relative">
      <form onSubmit={chercher} className="flex items-center gap-1 rounded-2xl bg-surface p-1 shadow-flottant" role="search">
        <Search className="ml-2 h-4 w-4 text-texte-pale" aria-hidden />
        <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Rechercher un lieu au Sénégal…" aria-label="Rechercher un lieu"
          className="w-full min-w-0 bg-transparent px-1 py-1.5 text-sm outline-none" />
        {q && <button type="button" onClick={() => { setQ(''); setResultats([]); setEtat(null); }} className="rounded-lg p-1.5 text-texte-pale hover:bg-surface-douce" aria-label="Effacer"><X className="h-4 w-4" /></button>}
        <button type="submit" className="rounded-xl bg-marque-600 px-3 py-1.5 text-xs font-bold text-white hover:bg-marque-700">{etat === 'chargement' ? '…' : 'OK'}</button>
      </form>
      {(resultats.length > 0 || (etat && etat !== 'chargement')) && (
        <ul className="absolute left-0 right-0 top-full mt-1 max-h-64 overflow-y-auto rounded-2xl bg-surface p-1 text-sm shadow-flottant">
          {etat === 'vide' && <li className="px-3 py-2 text-texte-doux">Aucun lieu trouvé.</li>}
          {etat && !['vide', 'chargement'].includes(etat) && <li className="px-3 py-2 text-red-700">{etat}</li>}
          {resultats.map((r) => (
            <li key={`${r.latitude}${r.longitude}`}>
              <button type="button" className="flex w-full gap-2 rounded-xl px-3 py-2 text-left hover:bg-surface-douce" onClick={() => { onChoix(r); setResultats([]); }}>
                <MapPin className="mt-0.5 h-4 w-4 shrink-0 text-marque-600" /><span className="line-clamp-2">{r.nom}</span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

/**
 * Carte plein écran à couches. `role` détermine les couches disponibles
 * (les données restent filtrées par le serveur selon les droits).
 */
export default function CarteAvancee({ role = 'citoyen', hauteur = 'calc(100vh - 11rem)' }) {
  const config = useConfig();
  const [params] = useSearchParams();
  const operationnel = role !== 'citoyen';
  const [fond, setFond] = useState('clair');
  const [jours, setJours] = useState('30');
  const [categorie, setCategorie] = useState('');
  const [couches, setCouches] = useState({ incidents: true, chaleur: false, risque: params.get('couche') === 'risque', alertes: true, dossiers: operationnel, sos: operationnel });
  const [panneau, setPanneau] = useState(true);
  const [cible, setCible] = useState(null);
  const [lieu, setLieu] = useState(null);
  const [message, setMessage] = useState(null);

  const carte = useRessource('/incidents/carte/', { jours, type_incident: categorie }, { intervalle: 60000 });
  const niveaux = useRessource('/analyse/niveaux-regions/', null, { actif: couches.risque });
  const alertes = useRessource('/alertes/zones/', { en_cours: 1 }, { actif: couches.alertes, intervalle: 120000 });
  const dossiers = useRessource('/incidents/', { actifs: true, taille: 100, type_incident: categorie }, { actif: operationnel && couches.dossiers, intervalle: 30000 });
  const sos = useRessource('/alertes/sos/', { actifs: true, taille: 100 }, { actif: operationnel && couches.sos, intervalle: 15000 });

  // Un dossier ouvert figure déjà dans sa couche (position exacte) : il n'est pas redessiné parmi les incidents.
  const incidentsRecents = useMemo(() => {
    const ouverts = new Set(operationnel && couches.dossiers ? (dossiers.donnees?.results || []).map((d) => d.id) : []);
    return (carte.donnees?.resultats || []).filter((p) => !ouverts.has(p.id));
  }, [carte.donnees, dossiers.donnees, couches.dossiers, operationnel]);

  const points = useMemo(() => {
    const pts = [];
    if (couches.incidents) {
      incidentsRecents.forEach((p) => {
        const c = config.categorie(p.type_incident);
        pts.push({ id: `c${p.id}`, lat: p.latitude, lng: p.longitude, couleur: c?.couleur || '#475569', titre: c?.libelle,
          popup: `<b>${echapper(c?.libelle || p.type_incident)}</b><br/>${echapper(STATUTS[p.statut]?.libelle)} · ${echapper(dateHeure(p.date_creation))}<br/><small>Position arrondie (~100 m)</small>` });
      });
    }
    if (operationnel && couches.dossiers) {
      (dossiers.donnees?.results || []).filter((d) => d.latitude != null).forEach((d) => pts.push({
        id: `d${d.id}`, lat: d.latitude, lng: d.longitude, couleur: STATUTS[d.statut].point, taille: 18,
        popup: `<b>${echapper(d.reference)}</b><br/>${echapper(d.categorie_libelle)} · ${echapper(STATUTS[d.statut].libelle)}<br/><a href="/app/${role === 'agent' ? 'agent/interventions' : 'supervision/incidents'}?dossier=${d.id}">Ouvrir le dossier</a> · <a target="_blank" rel="noreferrer" href="https://www.google.com/maps/dir/?api=1&destination=${d.latitude},${d.longitude}">Itinéraire</a>`,
      }));
    }
    if (operationnel && couches.sos) {
      (sos.donnees?.results || []).filter((d) => d.latitude != null).forEach((d) => pts.push({
        id: `s${d.id}`, lat: d.latitude, lng: d.longitude, couleur: '#E31B23', sos: true, taille: 20,
        popup: `<b>${echapper(d.reference)}</b><br/>Alerte SOS · ${echapper(STATUTS[d.statut].libelle)}<br/><a href="/app/${role === 'agent' ? 'agent/interventions?type=sos&' : 'supervision/sos?'}dossier=${d.id}">Ouvrir</a> · <a target="_blank" rel="noreferrer" href="https://www.google.com/maps/dir/?api=1&destination=${d.latitude},${d.longitude}">Itinéraire</a>`,
      }));
    }
    if (lieu) pts.push({ id: 'lieu', lat: lieu.lat, lng: lieu.lng, couleur: '#10231A', taille: 18, popup: echapper(lieu.nom) });
    return pts;
  }, [couches, incidentsRecents, dossiers.donnees, sos.donnees, lieu, config, operationnel, role]);

  const pointsChaleur = useMemo(() => (couches.chaleur ? (carte.donnees?.resultats || []).map((p) => ({ lat: p.latitude, lng: p.longitude, poids: p.gravite === 'critique' ? 1 : p.gravite === 'elevee' ? 0.8 : 0.5 })) : []), [couches.chaleur, carte.donnees]);

  const localiser = () => navigator.geolocation?.getCurrentPosition(
    (p) => {
      const l = { lat: p.coords.latitude, lng: p.coords.longitude, nom: `Ma position (± ${Math.round(p.coords.accuracy)} m)` };
      if (!L.latLngBounds(BORNES_SENEGAL).contains([l.lat, l.lng])) { setMessage('Votre position est hors du Sénégal : elle ne peut pas être affichée sur cette carte.'); return; }
      setMessage(null);
      setLieu(l);
      setCible({ ...l, zoom: 15 });
    },
    () => setMessage('Position refusée ou indisponible.'),
    { enableHighAccuracy: true, timeout: 10000 },
  );

  const Interrupteur = ({ cle, libelle, couleur }) => (
    <label className="flex cursor-pointer items-center justify-between gap-3 rounded-xl px-2.5 py-1.5 text-sm hover:bg-surface-douce">
      <span className="flex items-center gap-2"><span className="h-2.5 w-2.5 rounded-full" style={{ background: couleur }} aria-hidden />{libelle}</span>
      <input type="checkbox" className="h-4 w-4 accent-marque-600" checked={couches[cle]} onChange={(e) => setCouches((c) => ({ ...c, [cle]: e.target.checked }))} />
    </label>
  );

  return (
    <div className="relative overflow-hidden rounded-3xl border border-surface-bord shadow-carte" style={{ height: hauteur, minHeight: 480 }}>
      <MapContainer center={CENTRE_SENEGAL} zoom={7} minZoom={6} maxBounds={BORNES_SENEGAL} maxBoundsViscosity={1} className="h-full w-full" zoomControl={false} aria-label="Carte interactive SenAlert">
        <TileLayer key={fond} url={FONDS[fond].url} attribution={FONDS[fond].attribution} maxZoom={19} />
        <Marqueurs points={points} />
        {couches.chaleur && <CoucheChaleur points={pointsChaleur} />}
        {couches.risque && (niveaux.donnees?.zones || []).filter((z) => z.niveau !== 'faible').map((z) => (
          <Circle key={z.region} center={[z.latitude, z.longitude]} radius={z.niveau === 'critique' ? 32000 : z.niveau === 'eleve' ? 24000 : 16000}
            pathOptions={{ color: NIVEAUX_RISQUE[z.niveau].couleur, fillOpacity: 0.18, weight: 1.5, dashArray: z.donnees_insuffisantes ? '6 6' : undefined }}>
            <InfoBulle>{z.region_libelle} : risque {NIVEAUX_RISQUE[z.niveau].libelle.toLowerCase()}</InfoBulle>
          </Circle>
        ))}
        {couches.alertes && (alertes.donnees?.results || []).flatMap((a) => (a.regions.length ? a.regions : config.regions.map((r) => r.code)).map((code) => {
          const r = config.region(code);
          return r && (
            <Circle key={`${a.id}${code}`} center={[r.lat, r.lng]} radius={40000} pathOptions={{ color: COULEUR_ALERTE[a.niveau], weight: 3, fillOpacity: 0.08 }}>
              <InfoBulle sticky>{a.titre} — {r.libelle}</InfoBulle>
            </Circle>
          );
        }))}
        <Pilote cible={cible} />
      </MapContainer>

      {/* Recherche */}
      <div className="absolute left-3 right-3 top-3 z-[500] sm:right-auto sm:w-96"><RechercheAdresse onChoix={(r) => { const l = { lat: r.latitude, lng: r.longitude, nom: r.nom }; setLieu(l); setCible(l); }} /></div>

      {/* Boutons flottants */}
      <div className="absolute bottom-6 right-3 z-[500] flex flex-col gap-2">
        <button type="button" onClick={localiser} className="grid h-11 w-11 place-items-center rounded-2xl bg-surface shadow-flottant hover:bg-surface-douce" title="Me localiser" aria-label="Me localiser"><LocateFixed className="h-5 w-5 text-marque-700" /></button>
        <button type="button" onClick={() => setPanneau((p) => !p)} className="grid h-11 w-11 place-items-center rounded-2xl bg-surface shadow-flottant hover:bg-surface-douce" title="Couches" aria-label="Afficher les couches" aria-expanded={panneau}><Layers className="h-5 w-5 text-marque-700" /></button>
      </div>

      {/* Panneau des couches */}
      {panneau && (
        <div className="absolute right-3 top-16 z-[500] max-h-[calc(100%-9rem)] w-72 overflow-y-auto rounded-2xl bg-surface/95 p-3 shadow-flottant backdrop-blur sm:top-3">
          <div className="mb-2 flex items-center justify-between">
            <p className="text-sm font-bold">Couches</p>
            <IndicateurSynchro date={carte.derniereSynchro} chargement={carte.chargement} onRafraichir={carte.recharger} />
          </div>
          <div className="mb-3 grid grid-cols-3 gap-1 rounded-xl bg-surface-douce p-1" role="radiogroup" aria-label="Fond de carte">
            {Object.entries(FONDS).map(([k, f]) => (
              <button key={k} type="button" role="radio" aria-checked={fond === k} onClick={() => setFond(k)}
                className={clsx('rounded-lg py-1.5 text-xs font-semibold', fond === k ? 'bg-surface text-marque-700 shadow-sm' : 'text-texte-doux')}>{f.libelle}</button>
            ))}
          </div>
          <Interrupteur cle="incidents" libelle={`${operationnel ? 'Autres incidents récents' : 'Incidents récents'} (${carte.donnees ? incidentsRecents.length : '…'})`} couleur="#006E33" />
          <Interrupteur cle="chaleur" libelle="Carte de chaleur" couleur="#EA580C" />
          <Interrupteur cle="risque" libelle="Zones à risque" couleur="#E31B23" />
          <Interrupteur cle="alertes" libelle={`Alertes de zone (${alertes.donnees?.count ?? 0})`} couleur="#F5D90A" />
          {operationnel && <Interrupteur cle="dossiers" libelle={`Dossiers ouverts (${dossiers.donnees?.count ?? '…'})`} couleur="#1D4ED8" />}
          {operationnel && <Interrupteur cle="sos" libelle={`SOS actifs (${sos.donnees?.count ?? '…'})`} couleur="#E31B23" />}
          {message && <p className="mt-1 text-[11px] text-texte-doux">{message}</p>}
          <hr className="my-3 border-surface-bord" />
          <div className="grid grid-cols-2 gap-2">
            <Selecteur aria-label="Période" vide={null} valeur={jours} onChange={setJours} className="py-1.5 text-xs"
              options={[{ code: '7', libelle: '7 jours' }, { code: '30', libelle: '30 jours' }, { code: '90', libelle: '90 jours' }]} />
            <Selecteur aria-label="Catégorie" valeur={categorie} onChange={setCategorie} vide="Toutes" className="py-1.5 text-xs" options={config.categories} />
          </div>
          <div className="mt-3 space-y-1">
            {config.categories.map((c) => <p key={c.code} className="flex items-center gap-2 text-[11px] text-texte-doux"><span className="h-2 w-2 rounded-full" style={{ background: c.couleur }} />{c.libelle}</p>)}
          </div>
          {lieu && (
            <a className="mt-3 flex items-center gap-1.5 text-xs font-semibold text-marque-700 hover:underline" target="_blank" rel="noreferrer"
              href={`https://www.google.com/maps/dir/?api=1&destination=${lieu.lat},${lieu.lng}`}><Navigation className="h-3.5 w-3.5" /> Itinéraire vers le lieu choisi</a>
          )}
          <p className="mt-3 text-[10.5px] leading-snug text-texte-pale">L’absence d’incident ne signifie pas qu’une zone est sans danger. Positions publiques arrondies à ~100 m.</p>
        </div>
      )}
    </div>
  );
}
