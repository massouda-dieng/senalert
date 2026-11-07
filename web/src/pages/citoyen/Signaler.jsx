import clsx from 'clsx';
import { ArrowLeft, ArrowRight, Building2, Check, CheckCircle2, ImagePlus, Phone, Send, Trash2 } from 'lucide-react';
import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { api, nouvelleCle } from '../../api/client';
import { useRessource } from '../../api/hooks';
import SelecteurLieu from '../../components/SelecteurLieu';
import { Bandeau, Bouton, Chargement, Champ, EnTetePage } from '../../components/ui';
import { useConfig } from '../../lib/config';
import { dateHeure, distance } from '../../lib/format';
import { PHOTO_CATEGORIE } from '../../lib/photos';
import Photo from '../../components/Photo';

const CLE_BROUILLON = 'senalert.brouillon-signalement';
// Le citoyen choisit la structure concernée (la plus proche compétente pour la catégorie est suggérée) ;
// le superviseur de cette structure affecte ensuite un de ses agents.
const ETAPES = ['Type', 'Détails', 'Lieu', 'Structure', 'Envoi'];
const ETAPE_ENVOI = ETAPES.length - 1;
const TAILLE_MAX = 5 * 1024 * 1024;

const brouillonVide = () => ({
  cle: nouvelleCle(), type_incident: '', latitude: null, longitude: null, precision_gps: null, adresse: '', description: '', structure: null,
});
// Jamais envoyés au serveur : libellés de la vérification, et anciens champs de brouillon (la date, l'heure
// et la région sont désormais enregistrées automatiquement par le serveur).
const CHAMPS_AFFICHAGE = ['cle', 'service', 'agent', 'structure_nom', 'agent_libelle', 'date_incident', 'region', 'infos_complementaires'];

function lireBrouillon() {
  try { return { ...brouillonVide(), ...JSON.parse(localStorage.getItem(CLE_BROUILLON) || 'null') }; } catch { return brouillonVide(); }
}

export default function Signaler() {
  const config = useConfig();
  const [params] = useSearchParams();
  // Arrivée depuis une vignette de l'accueil (?type=incendie) : le type est déjà choisi.
  const typeDemande = config.categorie(params.get('type'))?.code;
  const [f, setF] = useState(() => (typeDemande ? { ...lireBrouillon(), type_incident: typeDemande } : lireBrouillon()));
  const [etape, setEtape] = useState(typeDemande ? 1 : 0);
  // La configuration peut arriver après le premier affichage : le type demandé est alors appliqué à son arrivée.
  const typeApplique = useRef(Boolean(typeDemande));
  useEffect(() => {
    if (typeApplique.current || !typeDemande) return;
    typeApplique.current = true;
    setF((x) => ({ ...x, type_incident: typeDemande }));
    setEtape(1);
  }, [typeDemande]);
  const [photos, setPhotos] = useState([]);
  const [envoi, setEnvoi] = useState(false);
  const [erreur, setErreur] = useState(null);
  const [resultat, setResultat] = useState(null);
  const maj = (k, v) => setF((x) => ({ ...x, [k]: v }));
  const categorie = config.categorie(f.type_incident);
  const apercus = useMemo(() => photos.map((p) => URL.createObjectURL(p)), [photos]);
  useEffect(() => () => apercus.forEach((u) => URL.revokeObjectURL(u)), [apercus]);

  // Sauvegarde automatique du brouillon (hors photos) : rien n'est perdu en cas de coupure.
  useEffect(() => { if (!resultat) { try { localStorage.setItem(CLE_BROUILLON, JSON.stringify(f)); } catch { /* rien */ } } }, [f, resultat]);



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
    Boolean(f.structure),
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
          Transmis à <b>{resultat.structure_nom || 'la supervision SenAlert'}</b> : son superviseur va l’affecter à un agent.
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
                  className={clsx('group overflow-hidden rounded-2xl border-2 text-left transition', f.type_incident === c.code ? 'border-marque-800 ring-2 ring-marque-800/20' : 'border-surface-bord hover:border-marque-600/40')}>
                  <Photo nom={PHOTO_CATEGORIE[c.code] || 'dakar-vue'} className="aspect-[16/10]" imgClassName="transition duration-300 group-hover:scale-[1.03]" alt="" credit={false} />
                  <span className="flex items-center gap-2 px-3 py-2.5 text-sm font-semibold">
                    <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ background: c.couleur }} aria-hidden />{c.libelle}
                  </span>
                </button>
              ))}
            </div>
            <p className="mt-3 text-xs text-texte-pale">Photos d’exemple (licence libre) : elles illustrent le type, elles ne montrent pas un incident réel.</p>
          </fieldset>
        )}

        {etape === 2 && (
          <div className="space-y-4">
            <SelecteurLieu lat={f.latitude} lng={f.longitude} precision={f.precision_gps}
              onLieu={(lat, lng, precision) => setF((x) => ({ ...x, latitude: lat, longitude: lng, precision_gps: precision }))} />
            <Champ libelle="Repère (facultatif)">{(id) => <input id={id} className="champ" maxLength={255} value={f.adresse} onChange={(e) => maj('adresse', e.target.value)} placeholder="Ex. : rond-point, près de la mosquée…" />}</Champ>
          </div>
        )}

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

        {etape === 3 && (
          <ChoixStructure categorie={f.type_incident} lat={f.latitude} lng={f.longitude} valeur={f.structure}
            onChange={(id, nom) => setF((x) => ({ ...x, structure: id, structure_nom: nom }))} />
        )}

        {etape === ETAPE_ENVOI && (
          <div className="space-y-4">
            <h2 className="font-bold">Vérifiez avant l’envoi</h2>
            <dl className="divide-y divide-surface-bord rounded-2xl border border-surface-bord text-sm">
              {[
                ['Type', categorie?.libelle],
                ['Description', f.description || '—'],
                ['Lieu', f.latitude != null ? `${f.latitude.toFixed(5)}, ${f.longitude.toFixed(5)}${f.precision_gps ? ` (GPS ± ${f.precision_gps} m)` : ''}` : '—'],
                ['Repère', f.adresse || '—'],
                ['Structure concernée', f.structure_nom || '—'],
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
          {etape < ETAPE_ENVOI ? (
            <Bouton disabled={!valide[etape]} onClick={() => setEtape((e) => e + 1)}>Continuer <ArrowRight className="h-4 w-4" /></Bouton>
          ) : (
            <Bouton icone={envoi ? undefined : Send} chargement={envoi} disabled={!valide.every(Boolean)} onClick={envoyer}>Envoyer le signalement</Bouton>
          )}
        </div>
      </div>
      {(f.type_incident || f.description) && etape < ETAPE_ENVOI && (
        <p className="mt-3 flex items-center gap-1.5 text-xs text-texte-pale"><Check className="h-3.5 w-3.5" /> Brouillon enregistré sur cet appareil. <button type="button" className="lien" onClick={() => { setF(brouillonVide()); setPhotos([]); setEtape(0); }}>Effacer</button></p>
      )}
    </div>
  );
}

/** Structures compétentes pour la catégorie, les plus proches du lieu d'abord ; la structure suggérée est cochée. */
function ChoixStructure({ categorie, lat, lng, valeur, onChange }) {
  const r = useRessource(lat != null ? '/structures/' : null, { lat, lng, categorie, limite: 6 });
  const liste = r.donnees || [];
  useEffect(() => {
    if (!liste.length || liste.some((s) => s.id === valeur)) return;
    const s = liste.find((x) => x.suggeree) || liste[0];
    onChange(s.id, s.nom);
  }, [liste, valeur]); // eslint-disable-line react-hooks/exhaustive-deps
  if (r.chargement) return <Chargement />;
  if (r.erreur) return <Bandeau type="danger" titre="Structures indisponibles">{r.erreur.detail}</Bandeau>;
  if (!liste.length) return <Bandeau type="alerte">Aucune structure compétente n’est référencée près de ce lieu : la supervision SenAlert recevra le signalement.</Bandeau>;
  return (
    <fieldset>
      <legend className="mb-1 font-bold">Quelle structure doit recevoir le signalement ?</legend>
      <p className="mb-4 text-sm text-texte-doux">Selon le type d’incident, la structure compétente la plus proche est proposée. Seul son superviseur verra votre signalement et l’affectera à un de ses agents.</p>
      <div className="space-y-2">
        {liste.map((s) => (
          <label key={s.id} className={clsx('flex cursor-pointer items-start gap-3 rounded-2xl border-2 p-3 transition', valeur === s.id ? 'border-marque-800 bg-marque-50/40' : 'border-surface-bord hover:border-marque-600/40')}>
            <input type="radio" name="structure" className="mt-1" checked={valeur === s.id} onChange={() => onChange(s.id, s.nom)} />
            <Building2 className="mt-0.5 h-5 w-5 shrink-0 text-marque-700" aria-hidden />
            <span className="min-w-0 flex-1">
              <span className="flex flex-wrap items-center gap-2 font-semibold">{s.nom}
                {s.suggeree && <span className="rounded-full bg-marque-50 px-2 py-0.5 text-xs font-semibold text-marque-700">Suggérée</span>}
              </span>
              <span className="block text-xs text-texte-doux">{s.service_nom} · {s.region_libelle}{s.distance_m != null ? ` · à ${distance(s.distance_m)}` : ''}</span>
              {s.telephone && <span className="mt-0.5 inline-flex items-center gap-1 text-xs text-texte-doux"><Phone className="h-3 w-3" />{s.telephone}</span>}
            </span>
          </label>
        ))}
      </div>
    </fieldset>
  );
}
