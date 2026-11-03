import clsx from 'clsx';
import { ArrowLeft, ArrowRight, Building2, Check, CheckCircle2, Crosshair, ImagePlus, Send, Trash2, UserRound } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, nouvelleCle } from '../../api/client';
import { useRessource } from '../../api/hooks';
import CarteSenAlert, { CENTRE_SENEGAL } from '../../components/Carte';
import { Bandeau, Bouton, Chargement, Champ, EnTetePage, Selecteur } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { lirePosition } from './Accueil';
import { COULEURS } from '../../lib/couleurs';

const CLE_BROUILLON = 'senalert.brouillon-signalement';
const ETAPES = ['Catégorie', 'Lieu', 'Structure', 'Détails', 'Vérification'];
const TAILLE_MAX = 5 * 1024 * 1024;

const brouillonVide = () => ({
  cle: nouvelleCle(), type_incident: '', latitude: null, longitude: null, precision_gps: null, region: '', adresse: '', description: '',
  date_incident: '', infos_complementaires: '', structure: '', agent: '', structure_nom: '', agent_libelle: '',
});
// Libellés affichés à la vérification : jamais envoyés au serveur.
const CHAMPS_AFFICHAGE = ['cle', 'structure_nom', 'agent_libelle'];
const km = (m) => `${(m / 1000).toFixed(1).replace('.', ',')} km`;

/**
 * Structures les plus proches du lieu (service compétent pour la catégorie), puis agents disponibles
 * de la structure choisie. Seuls le prénom et la fonction de l'agent sont montrés.
 */
function ChoixStructureAgent({ f, setF, onPropositions }) {
  const structures = useRessource('/structures/', { lat: f.latitude, lng: f.longitude, categorie: f.type_incident, limite: 5 });
  const agents = useRessource(f.structure ? `/structures/${f.structure}/agents/` : null);
  const liste = structures.donnees || [];
  const choisie = liste.find((s) => String(s.id) === String(f.structure));
  useEffect(() => { if (structures.donnees) onPropositions(liste.length); }, [structures.donnees]); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    // Lieu ou catégorie modifiés : une structure qui n'est plus proposée est oubliée.
    if (structures.donnees && f.structure && !choisie) setF((x) => ({ ...x, structure: '', agent: '', structure_nom: '', agent_libelle: '' }));
  }, [structures.donnees]); // eslint-disable-line react-hooks/exhaustive-deps

  if (structures.chargement && !structures.donnees) return <Chargement texte="Recherche des structures proches…" />;
  if (!liste.length) {
    return <Bandeau type="info">Aucune structure n’est enregistrée pour ce type d’incident : votre signalement sera orienté par la supervision.</Bandeau>;
  }
  const choisirStructure = (s) => setF((x) => ({ ...x, structure: String(s.id), structure_nom: s.nom, agent: '', agent_libelle: '' }));
  const choisirAgent = (a) => setF((x) => ({ ...x, agent: a ? String(a.id) : '', agent_libelle: a ? `${a.prenom} · ${a.fonction}` : '' }));
  return (
    <div className="space-y-5">
      <fieldset>
        <legend className="mb-3 font-bold">Structures les plus proches</legend>
        <div className="grid gap-2">
          {liste.map((s) => (
            <button key={s.id} type="button" onClick={() => choisirStructure(s)} aria-pressed={String(s.id) === String(f.structure)}
              className={clsx('flex items-center gap-3 rounded-2xl border-2 p-3 text-left transition', String(s.id) === String(f.structure) ? 'border-marque-800 bg-marque-50' : 'border-surface-bord hover:border-marque-600/40')}>
              <Building2 className="h-5 w-5 shrink-0 text-marque-700" aria-hidden />
              <span className="min-w-0 flex-1">
                <span className="block truncate text-sm font-semibold">{s.nom}</span>
                <span className="block text-xs text-texte-doux">{s.service_nom} · {s.region_libelle}{s.position_approximative ? ' · position approximative' : ''}</span>
              </span>
              <span className="shrink-0 text-right text-xs">
                <span className="block font-semibold tabular-nums">{km(s.distance_m)}</span>
                <span className={clsx('block', s.nb_agents_disponibles ? 'text-succes' : 'text-texte-pale')}>{s.nb_agents_disponibles ? `${s.nb_agents_disponibles} agent(s) disponible(s)` : 'aucun agent disponible'}</span>
              </span>
            </button>
          ))}
        </div>
      </fieldset>
      {choisie && (
        <fieldset>
          <legend className="mb-3 font-bold">Agent disponible</legend>
          {agents.chargement && !agents.donnees ? <Chargement /> : (
            <div className="grid gap-2 sm:grid-cols-2">
              {(agents.donnees || []).map((a) => (
                <button key={a.id} type="button" onClick={() => choisirAgent(a)} aria-pressed={String(a.id) === String(f.agent)}
                  className={clsx('flex items-center gap-3 rounded-2xl border-2 p-3 text-left transition', String(a.id) === String(f.agent) ? 'border-marque-800 bg-marque-50' : 'border-surface-bord hover:border-marque-600/40')}>
                  <UserRound className="h-5 w-5 shrink-0 text-marque-700" aria-hidden />
                  <span className="text-sm"><strong>{a.prenom}</strong> · {a.fonction} · {km(choisie.distance_m)}</span>
                </button>
              ))}
              <button type="button" onClick={() => choisirAgent(null)} aria-pressed={!f.agent}
                className={clsx('rounded-2xl border-2 p-3 text-left text-sm transition', !f.agent ? 'border-marque-800 bg-marque-50' : 'border-surface-bord hover:border-marque-600/40')}>
                Laisser le superviseur de la structure choisir l’agent
              </button>
            </div>
          )}
          {agents.donnees && !agents.donnees.length && <p className="mt-2 text-xs text-texte-doux">Aucun agent n’est disponible en ce moment : le superviseur de la structure affectera votre dossier.</p>}
        </fieldset>
      )}
    </div>
  );
}

function lireBrouillon() {
  try { return { ...brouillonVide(), ...JSON.parse(localStorage.getItem(CLE_BROUILLON) || 'null') }; } catch { return brouillonVide(); }
}

export default function Signaler() {
  const config = useConfig();
  const [f, setF] = useState(lireBrouillon);
  const [etape, setEtape] = useState(0);
  const [photos, setPhotos] = useState([]);
  const [gps, setGps] = useState(null);
  const [envoi, setEnvoi] = useState(false);
  const [erreur, setErreur] = useState(null);
  const [resultat, setResultat] = useState(null);
  const [propositions, setPropositions] = useState(null);
  const maj = (k, v) => setF((x) => ({ ...x, [k]: v }));
  const categorie = config.categorie(f.type_incident);
  const apercus = useMemo(() => photos.map((p) => URL.createObjectURL(p)), [photos]);
  useEffect(() => () => apercus.forEach((u) => URL.revokeObjectURL(u)), [apercus]);

  // Sauvegarde automatique du brouillon (hors photos) : rien n'est perdu en cas de coupure.
  useEffect(() => { if (!resultat) { try { localStorage.setItem(CLE_BROUILLON, JSON.stringify(f)); } catch { /* rien */ } } }, [f, resultat]);

  const localiser = async () => {
    setGps({ enCours: true });
    const p = await lirePosition({ delai: 15000 });
    setGps(p);
    if (p.lat != null) setF((x) => ({ ...x, latitude: p.lat, longitude: p.lng, precision_gps: Math.round(p.precision) }));
  };

  const ajouterPhotos = (liste) => {
    const valides = [];
    for (const p of liste) {
      if (!['image/jpeg', 'image/png', 'image/webp'].includes(p.type)) { setErreur({ detail: `« ${p.name} » : format non accepté (JPEG, PNG, WEBP).` }); continue; }
      if (p.size > TAILLE_MAX) { setErreur({ detail: `« ${p.name} » dépasse 5 Mo.` }); continue; }
      valides.push(p);
    }
    setPhotos((x) => [...x, ...valides].slice(0, 5));
  };

  const valide = [
    Boolean(f.type_incident),
    f.latitude != null,
    propositions === 0 || Boolean(f.structure),
    f.type_incident !== 'autre' || f.description.trim().length >= 10,
    true,
  ];

  const envoyer = async () => {
    setEnvoi(true);
    setErreur(null);
    const fd = new FormData();
    const champs = { ...f, client_request_id: f.cle };
    CHAMPS_AFFICHAGE.forEach((k) => delete champs[k]);
    Object.entries(champs).forEach(([k, v]) => { if (v !== null && v !== '') fd.append(k, k === 'date_incident' ? new Date(v).toISOString() : v); });
    photos.forEach((p) => fd.append('photos', p));
    try {
      const r = await api('/incidents/', { methode: 'POST', corps: fd });
      setResultat(r);
      try { localStorage.removeItem(CLE_BROUILLON); } catch { /* rien */ }
    } catch (e) {
      setErreur(e); // la clé est conservée : un nouvel essai ne créera pas de doublon
    } finally { setEnvoi(false); }
  };

  if (resultat) {
    return (
      <div className="mx-auto max-w-xl py-8 text-center">
        <CheckCircle2 className="mx-auto h-16 w-16 text-succes" />
        <h1 className="mt-4 text-2xl font-extrabold">Signalement enregistré</h1>
        <p className="mt-2 text-texte-doux">Référence de votre dossier :</p>
        <p className="mt-1 font-mono text-2xl font-bold text-marque-700">{resultat.reference}</p>
        <p className="mt-4 text-sm text-texte-doux">
          Transmis à {resultat.structure_nom || `au service ${resultat.service_nom || 'compétent'}`}
          {resultat.statut === 'affecte' ? ', à l’agent que vous avez choisi' : ', dont le superviseur va désigner un agent'}.
          Vous serez notifié à chaque changement de statut.
        </p>
        <div className="mt-6 flex justify-center gap-3">
          <Link to={`/citoyen/dossiers?dossier=${resultat.id}`}><Bouton>Suivre le dossier</Bouton></Link>
          <Bouton variante="secondaire" onClick={() => { setResultat(null); setF(brouillonVide()); setPhotos([]); setEtape(0); }}>Nouveau signalement</Bouton>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl">
      <EnTetePage titre="Signaler un incident" sousTitre="Pour une urgence vitale en cours, utilisez plutôt le bouton SOS et appelez les secours." />
      <ol className="mb-6 grid grid-cols-5 gap-2" aria-label="Étapes">
        {ETAPES.map((e, i) => (
          <li key={e} className="text-center">
            <div className={clsx('h-1.5 rounded-full', i <= etape ? 'bg-marque-800' : 'bg-surface-bord')} />
            <p className={clsx('mt-1.5 text-xs font-semibold', i === etape ? 'text-texte' : 'text-texte-pale')} aria-current={i === etape ? 'step' : undefined}>{i + 1}. {e}</p>
          </li>
        ))}
      </ol>

      <div className="carte p-5 sm:p-6">
        {etape === 0 && (
          <fieldset>
            <legend className="mb-4 font-bold">Quel type d’incident ?</legend>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              {config.categories.map((c) => (
                <button key={c.code} type="button" onClick={() => { maj('type_incident', c.code); setEtape(1); }} aria-pressed={f.type_incident === c.code}
                  className={clsx('rounded-2xl border-2 p-4 text-left transition', f.type_incident === c.code ? 'border-marque-800 bg-marque-50' : 'border-surface-bord hover:border-marque-600/40')}>
                  <span className="mb-2 block h-3 w-3 rounded-full" style={{ background: c.couleur }} aria-hidden />
                  <span className="text-sm font-semibold">{c.libelle}</span>
                </button>
              ))}
            </div>
          </fieldset>
        )}

        {etape === 1 && (
          <div className="space-y-4">
            <div className="flex flex-wrap items-center gap-3">
              <Bouton icone={Crosshair} chargement={gps?.enCours} onClick={localiser}>Utiliser ma position</Bouton>
              <span className="text-sm text-texte-doux">ou touchez la carte pour placer l’incident.</span>
            </div>
            {gps?.erreur && <Bandeau type="alerte">{gps.erreur}</Bandeau>}
            {f.latitude != null && (
              <p className="text-sm text-succes">Position retenue : {f.latitude.toFixed(5)}, {f.longitude.toFixed(5)}{f.precision_gps ? ` · ± ${f.precision_gps} m` : ' · choisie sur la carte'}</p>
            )}
            <CarteSenAlert hauteur={320} regrouper={false} cadrer={f.latitude != null} zoom={f.latitude != null ? 15 : 7}
              centre={f.latitude != null ? [f.latitude, f.longitude] : CENTRE_SENEGAL}
              points={f.latitude != null ? [{ id: 'p', lat: f.latitude, lng: f.longitude, couleur: categorie?.couleur || COULEURS.marine }] : []}
              onClic={(ll) => setF((x) => ({ ...x, latitude: ll.lat, longitude: ll.lng, precision_gps: null }))} />
            <div className="grid gap-4 sm:grid-cols-2">
              <Champ libelle="Région" aide="Déduite de la position si vous la laissez vide.">{(id) => <Selecteur id={id} valeur={f.region} onChange={(v) => maj('region', v)} vide="Automatique" options={config.regions} />}</Champ>
              <Champ libelle="Adresse ou repère">{(id) => <input id={id} className="champ" maxLength={255} value={f.adresse} onChange={(e) => maj('adresse', e.target.value)} placeholder="Ex. : rond-point, près de la mosquée…" />}</Champ>
            </div>
          </div>
        )}

        {etape === 2 && <ChoixStructureAgent f={f} setF={setF} onPropositions={setPropositions} />}

        {etape === 3 && (
          <div className="space-y-4">
            <Champ libelle="Description" requis={f.type_incident === 'autre'} aide={`${f.description.length}/2000 — décrivez ce que vous voyez (victimes, danger…).`}>
              {(id) => <textarea id={id} rows={4} className="champ" maxLength={2000} value={f.description} onChange={(e) => maj('description', e.target.value)} />}
            </Champ>
            <div className="grid gap-4 sm:grid-cols-2">
              <Champ libelle="Date et heure de l’incident" aide="Laisser vide si c’est maintenant.">{(id) => <input id={id} type="datetime-local" className="champ" value={f.date_incident} max={new Date().toISOString().slice(0, 16)} onChange={(e) => maj('date_incident', e.target.value)} />}</Champ>
              <Champ libelle="Informations complémentaires">{(id) => <input id={id} className="champ" maxLength={1000} value={f.infos_complementaires} onChange={(e) => maj('infos_complementaires', e.target.value)} placeholder="Nombre de personnes, accès…" />}</Champ>
            </div>
            <div>
              <p className="etiquette">Photos (5 maximum, 5 Mo chacune)</p>
              <div className="flex flex-wrap gap-2">
                {apercus.map((u, i) => (
                  <div key={u} className="relative">
                    <img src={u} alt={`Photo ${i + 1}`} className="h-20 w-20 rounded-xl object-cover" />
                    <button type="button" onClick={() => setPhotos((x) => x.filter((_, j) => j !== i))} className="absolute -right-1.5 -top-1.5 rounded-full bg-surface p-1 shadow" aria-label={`Retirer la photo ${i + 1}`}><Trash2 className="h-3.5 w-3.5 text-sos-fonce" /></button>
                  </div>
                ))}
                {photos.length < 5 && (
                  <label className="grid h-20 w-20 cursor-pointer place-items-center rounded-xl border-2 border-dashed border-surface-bord text-texte-pale hover:border-marque-600/40">
                    <ImagePlus className="h-6 w-6" /><span className="sr-only">Ajouter des photos</span>
                    <input type="file" accept="image/jpeg,image/png,image/webp" multiple className="sr-only" onChange={(e) => { ajouterPhotos([...e.target.files]); e.target.value = ''; }} />
                  </label>
                )}
              </div>
              <p className="mt-1.5 text-xs text-texte-pale">Les métadonnées (dont la position de l’appareil) sont supprimées par le serveur. Les photos ne sont pas conservées dans le brouillon.</p>
            </div>
          </div>
        )}

        {etape === 4 && (
          <div className="space-y-4">
            <h2 className="font-bold">Vérifiez avant l’envoi</h2>
            <dl className="divide-y divide-surface-bord rounded-2xl border border-surface-bord text-sm">
              {[
                ['Catégorie', categorie?.libelle],
                ['Structure', f.structure_nom || 'La plus proche du service compétent'],
                ['Agent', f.agent_libelle || 'Désigné par le superviseur de la structure'],
                ['Position', f.latitude != null ? `${f.latitude.toFixed(5)}, ${f.longitude.toFixed(5)}${f.precision_gps ? ` (± ${f.precision_gps} m)` : ''}` : '—'],
                ['Région', config.region(f.region)?.libelle || 'Déduite de la position'],
                ['Adresse / repère', f.adresse || '—'],
                ['Description', f.description || '—'],
                ['Photos', photos.length ? `${photos.length} photo(s)` : 'Aucune'],
              ].map(([k, v]) => (
                <div key={k} className="grid grid-cols-[150px_1fr] gap-3 px-4 py-2.5"><dt className="text-texte-doux">{k}</dt><dd className="whitespace-pre-wrap font-medium">{v}</dd></div>
              ))}
            </dl>
          </div>
        )}

        {erreur && <Bandeau type="danger" className="mt-4" titre="Le signalement n’a pas été enregistré">{erreur.detail} Vos informations sont conservées : vous pouvez réessayer.</Bandeau>}

        <div className="mt-6 flex items-center justify-between gap-3 border-t border-surface-bord pt-4">
          <Bouton variante="fantome" icone={ArrowLeft} disabled={etape === 0} onClick={() => setEtape((e) => e - 1)}>Retour</Bouton>
          {etape < 4 ? (
            <Bouton disabled={!valide[etape]} onClick={() => setEtape((e) => e + 1)}>Continuer <ArrowRight className="h-4 w-4" /></Bouton>
          ) : (
            <Bouton icone={envoi ? undefined : Send} chargement={envoi} disabled={!valide.every(Boolean)} onClick={envoyer}>Envoyer le signalement</Bouton>
          )}
        </div>
      </div>
      {(f.type_incident || f.description) && etape < 4 && (
        <p className="mt-3 flex items-center gap-1.5 text-xs text-texte-pale"><Check className="h-3.5 w-3.5" /> Brouillon enregistré sur cet appareil. <button type="button" className="lien" onClick={() => { setF(brouillonVide()); setPhotos([]); setEtape(0); }}>Effacer</button></p>
      )}
    </div>
  );
}
