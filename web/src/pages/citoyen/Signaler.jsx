import clsx from 'clsx';
import { ArrowLeft, ArrowRight, Building2, Check, CheckCircle2, Crosshair, ImagePlus, MapPin, Search, Send, Trash2, UserRound } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, nouvelleCle } from '../../api/client';
import { useRessource } from '../../api/hooks';
import CarteSenAlert, { CENTRE_SENEGAL } from '../../components/Carte';
import { Bandeau, Bouton, Chargement, Champ, EnTetePage } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { dateHeure } from '../../lib/format';
import { lirePosition } from './Accueil';
import { COULEURS } from '../../lib/couleurs';

const CLE_BROUILLON = 'senalert.brouillon-signalement';
const ETAPES = ['Type', 'Détails', 'Lieu', 'Structure', 'Envoi'];
const TAILLE_MAX = 5 * 1024 * 1024;

const brouillonVide = () => ({
  cle: nouvelleCle(), type_incident: '', latitude: null, longitude: null, precision_gps: null, adresse: '', description: '',
  service: '', structure: '', agent: '', structure_nom: '', agent_libelle: '',
});
// Jamais envoyés au serveur : libellés de la vérification, et anciens champs de brouillon (la date, l'heure
// et la région sont désormais enregistrées automatiquement par le serveur).
const CHAMPS_AFFICHAGE = ['cle', 'service', 'structure_nom', 'agent_libelle', 'date_incident', 'region', 'infos_complementaires'];
const km = (m) => `${(m / 1000).toFixed(1).replace('.', ',')} km`;

/**
 * Structures les plus proches du lieu (service compétent pour la catégorie), puis agents disponibles
 * de la structure choisie. Seuls le prénom et la fonction de l'agent sont montrés.
 */
function ChoixStructureAgent({ f, setF, onPropositions }) {
  const config = useConfig();
  // « Autre incident » n'a pas de service compétent par défaut : le citoyen le choisit.
  const sansService = !config.categorie(f.type_incident)?.service_defaut;
  const structures = useRessource(sansService && !f.service ? null : '/structures/',
    { lat: f.latitude, lng: f.longitude, categorie: f.type_incident, service: f.service || undefined, limite: 5 });
  const agents = useRessource(f.structure ? `/structures/${f.structure}/agents/` : null);
  const liste = structures.donnees || [];
  const choisie = liste.find((s) => String(s.id) === String(f.structure));
  useEffect(() => { if (structures.donnees) onPropositions(liste.length); }, [structures.donnees]); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    // Lieu ou catégorie modifiés : une structure qui n'est plus proposée est oubliée.
    if (structures.donnees && f.structure && !choisie) setF((x) => ({ ...x, structure: '', agent: '', structure_nom: '', agent_libelle: '' }));
  }, [structures.donnees]); // eslint-disable-line react-hooks/exhaustive-deps

  const choixService = sansService && (
    <fieldset className="mb-5">
      <legend className="mb-3 font-bold">Quel service doit intervenir ?</legend>
      <div className="flex flex-wrap gap-2">
        {config.services.map((s) => (
          <button key={s.code} type="button" aria-pressed={f.service === s.code}
            onClick={() => setF((x) => ({ ...x, service: s.code, structure: '', agent: '', structure_nom: '', agent_libelle: '' }))}
            className={clsx('rounded-full border-2 px-3.5 py-1.5 text-sm font-semibold transition', f.service === s.code ? 'border-marque-800 bg-marque-50' : 'border-surface-bord hover:border-marque-600/40')}>
            {s.libelle}
          </button>
        ))}
      </div>
    </fieldset>
  );
  if (sansService && !f.service) return choixService;
  if (structures.chargement && !structures.donnees) return <>{choixService}<Chargement texte="Recherche des structures proches…" /></>;
  if (!liste.length) {
    return <>{choixService}<Bandeau type="info">Aucune structure de ce service n’est enregistrée près de ce lieu : vous pouvez envoyer, la supervision orientera votre signalement.</Bandeau></>;
  }
  const choisirStructure = (s) => setF((x) => ({ ...x, structure: String(s.id), structure_nom: s.nom, agent: '', agent_libelle: '' }));
  const choisirAgent = (a) => setF((x) => ({ ...x, agent: a ? String(a.id) : '', agent_libelle: a ? `${a.prenom} · ${a.fonction}` : '' }));
  return (
    <div className="space-y-5">
      {choixService}
      <fieldset>
        <legend className="mb-3 font-bold">Structures compétentes les plus proches</legend>
        <div className="grid gap-2">
          {liste.map((s) => (
            <button key={s.id} type="button" onClick={() => choisirStructure(s)} aria-pressed={String(s.id) === String(f.structure)}
              className={clsx('flex items-center gap-3 rounded-2xl border-2 p-3 text-left transition', String(s.id) === String(f.structure) ? 'border-marque-800 bg-marque-50' : 'border-surface-bord hover:border-marque-600/40')}>
              <Building2 className="h-5 w-5 shrink-0 text-marque-700" aria-hidden />
              <span className="min-w-0 flex-1">
                <span className="block truncate text-sm font-semibold">{s.nom}</span>
                <span className="block text-xs text-texte-doux">{s.service_nom} · {s.adresse || s.region_libelle}{s.position_approximative ? ' · position approximative' : ''}</span>
                {s.dans_la_zone === false && <span className="block text-xs font-semibold text-alerte">Hors de la région du lieu</span>}
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
    f.type_incident !== 'autre' || f.description.trim().length >= 10,
    f.latitude != null,
    propositions === 0 || Boolean(f.structure),
    true,
  ];

  const envoyer = async () => {
    if (envoi) return; // un seul envoi, même en cas de double clic
    setEnvoi(true);
    setErreur(null);
    const fd = new FormData();
    const champs = { ...f, client_request_id: f.cle };
    CHAMPS_AFFICHAGE.forEach((k) => delete champs[k]);
    Object.entries(champs).forEach(([k, v]) => { if (v !== null && v !== '') fd.append(k, v); });
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
        <h1 className="mt-4 text-2xl font-extrabold">Signalement envoyé</h1>
        <p className="mt-2 text-texte-doux">Référence de votre dossier :</p>
        <p className="mt-1 font-mono text-2xl font-bold text-marque-700">{resultat.reference}</p>
        <p className="mt-2 text-sm text-texte-doux">Enregistré le {dateHeure(resultat.date_creation)} · statut « {resultat.statut_libelle} »</p>
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

        {etape === 2 && (
          <div className="space-y-4">
            <RechercheLieu onLieu={(lat, lng) => setF((x) => ({ ...x, latitude: lat, longitude: lng, precision_gps: null }))} />
            <div className="flex flex-wrap items-center gap-3">
              <Bouton icone={Crosshair} chargement={gps?.enCours} onClick={localiser}>Utiliser ma position actuelle</Bouton>
              <span className="text-sm text-texte-doux">ou touchez la carte pour placer l’incident.</span>
            </div>
            {gps?.erreur && <Bandeau type="alerte">{gps.erreur} Recherchez l’adresse ou touchez la carte à l’endroit de l’incident.</Bandeau>}
            {f.latitude != null && (
              <p className="text-sm text-succes">Position retenue : {f.latitude.toFixed(5)}, {f.longitude.toFixed(5)}{f.precision_gps ? ` · ± ${f.precision_gps} m` : ' · choisie sur la carte'}</p>
            )}
            <CarteSenAlert hauteur={320} regrouper={false} cadrer={f.latitude != null} zoom={f.latitude != null ? 15 : 7}
              centre={f.latitude != null ? [f.latitude, f.longitude] : CENTRE_SENEGAL}
              points={f.latitude != null ? [{ id: 'p', lat: f.latitude, lng: f.longitude, couleur: categorie?.couleur || COULEURS.marine }] : []}
              onClic={(ll) => setF((x) => ({ ...x, latitude: ll.lat, longitude: ll.lng, precision_gps: null }))} />
            <Champ libelle="Repère (facultatif)">{(id) => <input id={id} className="champ" maxLength={255} value={f.adresse} onChange={(e) => maj('adresse', e.target.value)} placeholder="Ex. : rond-point, près de la mosquée…" />}</Champ>
          </div>
        )}

        {etape === 3 && <ChoixStructureAgent f={f} setF={setF} onPropositions={setPropositions} />}

        {etape === 1 && (
          <div className="space-y-4">
            <Champ libelle="Description" requis={f.type_incident === 'autre'} aide={`${f.description.length}/2000 — décrivez ce que vous voyez (victimes, danger…).`}>
              {(id) => <textarea id={id} rows={4} className="champ" maxLength={2000} value={f.description} onChange={(e) => maj('description', e.target.value)} />}
            </Champ>
            <div>
              <p className="etiquette">Photo (facultative · 5 maximum, 5 Mo chacune, JPEG, PNG ou WEBP)</p>
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
                ['Type', categorie?.libelle],
                ['Description', f.description || '—'],
                ['Lieu', f.latitude != null ? `${f.latitude.toFixed(5)}, ${f.longitude.toFixed(5)}${f.precision_gps ? ` (GPS ± ${f.precision_gps} m)` : ''}` : '—'],
                ['Repère', f.adresse || '—'],
                ['Destinataire', f.structure_nom || 'Structure compétente la plus proche'],
                ['Agent', f.agent_libelle || 'Désigné par le superviseur de la structure'],
                ['Date et heure', 'Enregistrées automatiquement à l’envoi'],
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
