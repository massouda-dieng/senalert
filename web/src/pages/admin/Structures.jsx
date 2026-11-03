import { MapPin, Pencil, Plus } from 'lucide-react';
import { useState } from 'react';
import { api } from '../../api/client';
import { useRessource } from '../../api/hooks';
import { Bandeau, Bouton, Champ, Chargement, EnTetePage, EtatErreur, Fenetre, Selecteur, useToast } from '../../components/ui';
import { useConfig } from '../../lib/config';

const VIDE = { nom: '', service: '', region: '', latitude: '', longitude: '', adresse: '', telephone: '', actif: true };

/** Création ou correction d'une structure : la position sert à proposer la structure la plus proche au citoyen. */
function FormulaireStructure({ structure, services, onFermer, onFait }) {
  const config = useConfig();
  const [f, setF] = useState(structure ? {
    ...VIDE, ...structure, service: String(structure.service), latitude: String(structure.latitude), longitude: String(structure.longitude),
  } : VIDE);
  const [erreurs, setErreurs] = useState({});
  const [erreur, setErreur] = useState(null);
  const [envoi, setEnvoi] = useState(false);
  const maj = (k) => (e) => setF((x) => ({ ...x, [k]: e?.target ? e.target.value : e }));
  const maPosition = () => navigator.geolocation?.getCurrentPosition(
    (p) => setF((x) => ({ ...x, latitude: p.coords.latitude.toFixed(6), longitude: p.coords.longitude.toFixed(6) })),
    () => setErreur('Position indisponible : saisissez les coordonnées.'),
  );
  return (
    <Fenetre ouverte large onFermer={onFermer} titre={structure ? `Modifier ${structure.nom}` : 'Nouvelle structure'} pied={<>
      <Bouton variante="secondaire" onClick={onFermer}>Annuler</Bouton>
      <Bouton chargement={envoi} onClick={async () => {
        setEnvoi(true); setErreur(null); setErreurs({});
        const corps = { nom: f.nom, service: Number(f.service), region: f.region, latitude: Number(f.latitude), longitude: Number(f.longitude),
          adresse: f.adresse, telephone: f.telephone, actif: f.actif };
        try {
          await api(structure ? `/structures/${structure.id}/` : '/structures/', { methode: structure ? 'PATCH' : 'POST', corps });
          onFait(); onFermer();
        } catch (e) { setErreurs(e.champs || {}); setErreur(e.detail); } finally { setEnvoi(false); }
      }}>Enregistrer</Bouton>
    </>}>
      {structure?.position_approximative && <Bandeau type="alerte" className="mb-4">Position provisoire (chef-lieu de région) : indiquez l’emplacement réel de l’agence pour que les citoyens voient la bonne distance.</Bandeau>}
      <div className="grid gap-4 sm:grid-cols-2">
        <Champ libelle="Nom" requis erreur={erreurs.nom}>{(id) => <input id={id} className="champ" value={f.nom} onChange={maj('nom')} />}</Champ>
        <Champ libelle="Service" requis erreur={erreurs.service}>{(id) => <Selecteur id={id} valeur={f.service} onChange={maj('service')} vide="Choisir…" options={services.map((s) => ({ code: String(s.id), libelle: s.nom }))} />}</Champ>
        <Champ libelle="Région" requis erreur={erreurs.region}>{(id) => <Selecteur id={id} valeur={f.region} onChange={maj('region')} vide="Choisir…" options={config.regions} />}</Champ>
        <Champ libelle="Téléphone" erreur={erreurs.telephone}>{(id) => <input id={id} className="champ" value={f.telephone} onChange={maj('telephone')} />}</Champ>
        <Champ libelle="Latitude" requis erreur={erreurs.latitude}>{(id) => <input id={id} className="champ" inputMode="decimal" value={f.latitude} onChange={maj('latitude')} placeholder="14.6928" />}</Champ>
        <Champ libelle="Longitude" requis erreur={erreurs.longitude}>{(id) => <input id={id} className="champ" inputMode="decimal" value={f.longitude} onChange={maj('longitude')} placeholder="-17.4467" />}</Champ>
        <Champ libelle="Adresse" erreur={erreurs.adresse}>{(id) => <input id={id} className="champ" value={f.adresse} onChange={maj('adresse')} />}</Champ>
        <Champ libelle="État">{(id) => <Selecteur id={id} vide={null} valeur={f.actif ? '1' : '0'} onChange={(v) => setF((x) => ({ ...x, actif: v === '1' }))} options={[{ code: '1', libelle: 'Active' }, { code: '0', libelle: 'Désactivée' }]} />}</Champ>
      </div>
      <Bouton variante="fantome" taille="sm" icone={MapPin} className="mt-3" onClick={maPosition}>Utiliser ma position actuelle</Bouton>
      {erreur && <Bandeau type="danger" className="mt-4">{erreur}</Bandeau>}
    </Fenetre>
  );
}

export default function Structures() {
  const config = useConfig();
  const toast = useToast();
  const [filtres, setFiltres] = useState({ service: '', region: '', q: '' });
  const [edition, setEdition] = useState(null);
  const liste = useRessource('/structures/', { service: filtres.service || undefined, region: filtres.region || undefined, q: filtres.q || undefined });
  const services = useRessource('/services/');
  const svc = (services.donnees || []).filter((s) => s.actif);
  const maj = (k) => (v) => setFiltres((f) => ({ ...f, [k]: v }));
  const lignes = liste.donnees || [];
  const aConfirmer = lignes.filter((s) => s.position_approximative).length;

  return (
    <>
      <EnTetePage titre="Structures" sousTitre={liste.donnees ? `${lignes.length} structure(s) · casernes, commissariats, hôpitaux, agences SENELEC et ONAS` : ''}
        actions={<Bouton icone={Plus} onClick={() => setEdition('nouvelle')}>Nouvelle structure</Bouton>} />
      <Bandeau type="info" className="mb-4">Chaque structure a un superviseur et ses agents. Le citoyen se voit proposer les structures les plus proches du lieu de l’incident : la position doit donc être exacte. Les structures viennent d’OpenStreetMap ; les agences SENELEC et ONAS sont placées au chef-lieu de région en attendant leur position réelle{aConfirmer ? ` (${aConfirmer} à confirmer dans cette liste)` : ''}.</Bandeau>
      <div className="carte mb-4 flex flex-wrap gap-3 p-3">
        <input className="champ w-56 py-2" placeholder="Nom…" aria-label="Recherche" onKeyDown={(e) => e.key === 'Enter' && maj('q')(e.currentTarget.value)} onBlur={(e) => maj('q')(e.currentTarget.value)} />
        <Selecteur aria-label="Service" className="w-auto" valeur={filtres.service} onChange={maj('service')} vide="Tous services" options={svc.map((s) => ({ code: s.code, libelle: s.nom }))} />
        <Selecteur aria-label="Région" className="w-auto" valeur={filtres.region} onChange={maj('region')} vide="Toutes régions" options={config.regions} />
      </div>
      <EtatErreur erreur={liste.erreur} onReessayer={liste.recharger} />
      <div className="carte overflow-x-auto">
        {liste.chargement && !liste.donnees ? <Chargement /> : (
          <table className="w-full min-w-[720px] text-sm">
            <thead className="bg-surface-douce text-left text-xs uppercase text-texte-doux">
              <tr><th className="px-4 py-2.5">Structure</th><th className="px-4 py-2.5">Service</th><th className="px-4 py-2.5">Région</th><th className="px-4 py-2.5">Position</th><th className="px-4 py-2.5" /></tr>
            </thead>
            <tbody className="divide-y divide-surface-bord">
              {lignes.slice(0, 300).map((s) => (
                <tr key={s.id} className={s.actif ? '' : 'opacity-60'}>
                  <td className="px-4 py-3"><p className="font-semibold">{s.nom}</p>{s.telephone && <p className="text-xs text-texte-doux">{s.telephone}</p>}</td>
                  <td className="px-4 py-3">{s.service_nom}</td>
                  <td className="px-4 py-3">{s.region_libelle}</td>
                  <td className="px-4 py-3 text-xs tabular-nums text-texte-doux">
                    {s.latitude.toFixed(4)}, {s.longitude.toFixed(4)}
                    {s.position_approximative && <span className="ml-2 rounded bg-alerte-clair px-1.5 text-[10px] font-bold uppercase text-alerte">à confirmer</span>}
                  </td>
                  <td className="px-4 py-3 text-right"><Bouton variante="fantome" taille="sm" icone={Pencil} onClick={() => setEdition(s)} aria-label={`Modifier ${s.nom}`}>Modifier</Bouton></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        {lignes.length > 300 && <p className="border-t border-surface-bord p-3 text-xs text-texte-doux">300 premières structures affichées : affinez avec les filtres.</p>}
      </div>
      {edition && <FormulaireStructure structure={edition === 'nouvelle' ? null : edition} services={svc}
        onFermer={() => setEdition(null)} onFait={() => { liste.recharger(true); toast('Structure enregistrée.'); }} />}
    </>
  );
}
