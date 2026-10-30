import { Crosshair, ExternalLink, Navigation, Phone } from 'lucide-react';
import { useMemo, useState } from 'react';
import { api } from '../../api/client';
import CarteSenAlert, { Legende, echapper } from '../../components/Carte';
import { Bandeau, Bouton, Carte, EnTetePage, EtatVide, Selecteur } from '../../components/ui';
import { dateHeure, distance } from '../../lib/format';
import { lirePosition } from './Accueil';

const TYPES = {
  hopital: { libelle: 'Hôpitaux', couleur: '#E31B23' },
  clinique: { libelle: 'Cliniques', couleur: '#F97316' },
  pharmacie: { libelle: 'Pharmacies', couleur: '#059669' },
  police: { libelle: 'Police / gendarmerie', couleur: '#1D4ED8' },
  pompiers: { libelle: 'Sapeurs-pompiers', couleur: '#B45309' },
};

export default function Services() {
  const [position, setPosition] = useState(null);
  const [type, setType] = useState('');
  const [rayon, setRayon] = useState('5000');
  const [donnees, setDonnees] = useState(null);
  const [etat, setEtat] = useState({ chargement: false, erreur: null });

  const chercher = async (pos = position) => {
    if (!pos) return;
    setEtat({ chargement: true, erreur: null });
    try {
      setDonnees(await api('/services-proximite/', { params: { lat: pos.lat, lng: pos.lng, rayon, type: type || undefined } }));
      setEtat({ chargement: false, erreur: null });
    } catch (e) { setEtat({ chargement: false, erreur: e.detail }); }
  };
  const localiser = async () => {
    setEtat({ chargement: true, erreur: null });
    const p = await lirePosition();
    if (p.erreur) { setEtat({ chargement: false, erreur: p.erreur }); return; }
    setPosition(p);
    chercher(p);
  };
  const points = useMemo(() => [
    ...(position ? [{ id: 'moi', lat: position.lat, lng: position.lng, couleur: '#006E33', titre: 'Ma position', popup: 'Ma position' }] : []),
    ...(donnees?.resultats || []).map((s) => ({ id: s.id, lat: s.latitude, lng: s.longitude, couleur: TYPES[s.type].couleur, titre: s.nom,
      popup: `<b>${echapper(s.nom || 'Sans nom')}</b><br/>${echapper(TYPES[s.type].libelle)} · ${echapper(distance(s.distance_m))}` })),
  ], [position, donnees]);

  return (
    <>
      <EnTetePage titre="Services de proximité" sousTitre="Hôpitaux, pharmacies, police et sapeurs-pompiers autour de vous, d’après OpenStreetMap." />
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <Bouton icone={Crosshair} chargement={etat.chargement} onClick={localiser}>{position ? 'Actualiser ma position' : 'Me localiser'}</Bouton>
        <Selecteur aria-label="Type" className="w-auto" valeur={type} onChange={setType} vide="Tous les services" options={Object.entries(TYPES).map(([code, t]) => ({ code, libelle: t.libelle }))} />
        <Selecteur aria-label="Rayon" className="w-auto" vide={null} valeur={rayon} onChange={setRayon} options={[{ code: '2000', libelle: '2 km' }, { code: '5000', libelle: '5 km' }, { code: '10000', libelle: '10 km' }, { code: '20000', libelle: '20 km' }]} />
        {position && <Bouton variante="secondaire" onClick={() => chercher()}>Rechercher</Bouton>}
      </div>
      {etat.erreur && <Bandeau type="danger" className="mb-4">{etat.erreur}</Bandeau>}
      {!position && !etat.chargement && <EtatVide icone={Crosshair} titre="Autorisez la localisation" texte="Votre position sert uniquement à cette recherche. Elle est arrondie (~1 km) avant d’interroger OpenStreetMap." />}
      {position && (
        <div className="grid gap-5 lg:grid-cols-[1fr_420px]">
          <Carte corpsClassName="space-y-3 p-3">
            <CarteSenAlert points={points} hauteur={520} cadrer regrouper={false} />
            <Legende elements={Object.values(TYPES)} />
          </Carte>
          <Carte titre={donnees ? `${donnees.resultats.length} résultat(s)` : 'Résultats'} corpsClassName="max-h-[560px] overflow-y-auto p-0">
            {donnees?.resultats.length === 0 && <p className="p-5 text-sm text-texte-doux">Aucun établissement référencé dans ce rayon. Élargissez la recherche.</p>}
            <ul className="divide-y divide-surface-bord">
              {donnees?.resultats.map((s) => (
                <li key={s.id} className="px-5 py-3">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="font-semibold">{s.nom || <span className="italic text-texte-doux">Nom non renseigné</span>}</p>
                      <p className="text-xs text-texte-doux">{TYPES[s.type].libelle}{s.adresse ? ` · ${s.adresse}` : ''}{s.horaires ? ` · ${s.horaires}` : ''}</p>
                    </div>
                    <span className="whitespace-nowrap text-sm font-semibold text-marque-700">{distance(s.distance_m)}</span>
                  </div>
                  <div className="mt-2 flex gap-4 text-sm">
                    {s.telephone && <a className="lien inline-flex items-center gap-1" href={`tel:${s.telephone}`}><Phone className="h-3.5 w-3.5" />{s.telephone}</a>}
                    <a className="lien inline-flex items-center gap-1" target="_blank" rel="noreferrer" href={`https://www.google.com/maps/dir/?api=1&destination=${s.latitude},${s.longitude}`}><Navigation className="h-3.5 w-3.5" />Itinéraire<ExternalLink className="h-3 w-3" /></a>
                  </div>
                </li>
              ))}
            </ul>
          </Carte>
        </div>
      )}
      {donnees && <p className="mt-3 text-xs text-texte-pale">{donnees.source} · données du {dateHeure(donnees.donnees_du)}{donnees.donnees_anciennes && <b> (serveurs OpenStreetMap saturés : derniers résultats connus)</b>}. {donnees.avertissement}</p>}
    </>
  );
}
