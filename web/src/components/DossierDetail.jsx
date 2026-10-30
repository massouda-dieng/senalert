import clsx from 'clsx';
import {
  CheckCircle2, Clock, Copy, ExternalLink, Flag, ImagePlus, MapPin, MessageSquarePlus, Navigation, Phone, Play,
  Send, UserPlus, X, XCircle,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { api, urlObjetProtege } from '../api/client';
import { useRessource } from '../api/hooks';
import { useAuth } from '../auth/AuthContext';
import { useConfig } from '../lib/config';
import { GRAVITES, STATUTS, dateHeure, duree, ilYa } from '../lib/format';
import CarteSenAlert from './Carte';
import {
  BadgeGravite, BadgeStatut, Bandeau, Bouton, Champ, Chargement, Confirmation, EtatErreur, Fenetre, Selecteur, useToast,
} from './ui';

const chemin = (type, id) => (type === 'sos' ? `/alertes/sos/${id}/` : `/incidents/${id}/`);

export default function DossierDetail({ type = 'incident', id, onFermer, onModifie, compact = false }) {
  const { utilisateur } = useAuth();
  const toast = useToast();
  const { donnees: d, chargement, erreur, recharger, setDonnees } = useRessource(id ? chemin(type, id) : null);
  const evs = useRessource(id ? `${chemin(type, id)}evenements/` : null);
  const [dialogue, setDialogue] = useState(null);

  if (!id) return null;
  if (chargement && !d) return <Chargement />;
  if (erreur) return <EtatErreur erreur={erreur} onReessayer={recharger} />;
  if (!d) return null;

  const role = utilisateur.role;
  const inter = d.intervention;
  const estMien = inter?.agent === utilisateur.id;
  const s = d.statut;

  const agir = async (action, corps, message) => {
    try {
      const maj = await api(`${chemin(type, id)}${action}/`, { methode: 'POST', corps });
      setDonnees(maj);
      evs.recharger(true);
      onModifie?.(maj);
      toast(message);
    } catch (e) {
      toast(e.detail, 'erreur');
      if (e.status === 409) { recharger(true); evs.recharger(true); }
      throw e;
    }
  };

  const actions = [];
  if (role === 'citoyen' && d.est_proprietaire && ['nouveau', 'affecte'].includes(s)) {
    actions.push(<Bouton key="annuler" variante="secondaire" icone={XCircle} onClick={() => setDialogue('annuler')}>Annuler mon signalement</Bouton>);
  }
  if (role === 'citoyen' && d.est_proprietaire && !['resolu', 'refuse', 'annule'].includes(s)) {
    actions.push(<Bouton key="completer" variante="secondaire" icone={MessageSquarePlus} onClick={() => setDialogue('completer')}>Compléter</Bouton>);
  }
  if (role === 'agent') {
    if (s === 'nouveau') actions.push(<Bouton key="pec" icone={CheckCircle2} onClick={() => agir('prendre-en-charge', undefined, 'Dossier pris en charge.').catch(() => {})}>Prendre en charge</Bouton>);
    if (s === 'affecte' && estMien) {
      actions.push(<Bouton key="acc" icone={CheckCircle2} onClick={() => agir('accepter', undefined, 'Intervention acceptée.').catch(() => {})}>Accepter</Bouton>);
      actions.push(<Bouton key="dec" variante="secondaire" icone={X} onClick={() => setDialogue('decliner')}>Décliner</Bouton>);
    }
    if (s === 'accepte' && estMien) actions.push(<Bouton key="dem" icone={Play} onClick={() => agir('demarrer', undefined, 'Intervention démarrée.').catch(() => {})}>Démarrer l’intervention</Bouton>);
    if (['accepte', 'en_cours'].includes(s) && estMien) actions.push(<Bouton key="res" variante="succes" icone={Flag} onClick={() => setDialogue('resoudre')}>Clôturer (résolu)</Bouton>);
  }
  if (role === 'superadmin') {
    if (['nouveau', 'affecte', 'accepte', 'en_cours'].includes(s)) actions.push(<Bouton key="aff" icone={UserPlus} onClick={() => setDialogue('affecter')}>{inter?.agent ? 'Réaffecter' : 'Affecter'}</Bouton>);
    if (s === 'nouveau') actions.push(<Bouton key="rej" variante="secondaire" onClick={() => setDialogue('rejeter')}>Rejeter</Bouton>);
    if (['nouveau', 'affecte', 'accepte', 'en_cours'].includes(s)) actions.push(<Bouton key="ann" variante="secondaire" icone={XCircle} onClick={() => setDialogue('annuler')}>Annuler</Bouton>);
  }
  const peutNoter = role === 'superadmin' || (role === 'agent' && estMien);
  const peutGravite = (role === 'superadmin' || (role === 'agent' && estMien)) && !['resolu', 'refuse', 'annule'].includes(s);

  return (
    <div className="space-y-5">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <button type="button" className="group inline-flex items-center gap-1.5 font-mono text-sm font-bold text-nuit-700"
              onClick={() => { navigator.clipboard?.writeText(d.reference); toast('Référence copiée.', 'info'); }} title="Copier la référence">
              {d.reference}<Copy className="h-3.5 w-3.5 opacity-0 transition group-hover:opacity-100" />
            </button>
            <BadgeStatut statut={s} />
            <BadgeGravite gravite={d.gravite} />
            {d.en_retard && <span className="inline-flex items-center gap-1 rounded-full bg-alerte-clair px-2 py-0.5 text-xs font-semibold text-amber-800"><Clock className="h-3 w-3" /> En retard</span>}
          </div>
          <h2 className="mt-1.5 text-xl font-extrabold">{type === 'sos' ? 'Alerte SOS' : d.categorie_libelle}</h2>
          <p className="text-sm text-texte-doux">{d.region_libelle || 'Région inconnue'} · créé {ilYa(d.date_creation)} ({dateHeure(d.date_creation)})</p>
        </div>
        {onFermer && <button type="button" onClick={onFermer} className="rounded-lg p-1.5 text-texte-doux hover:bg-surface-douce" aria-label="Fermer le détail"><X className="h-5 w-5" /></button>}
      </div>

      {actions.length > 0 && <div className="flex flex-wrap gap-2">{actions}</div>}

      {d.doublon_potentiel_reference && (
        <Bandeau type="alerte" titre="Doublon potentiel">Ce signalement ressemble à {d.doublon_potentiel_reference} (même catégorie, à proximité, peu de temps avant). Vérifiez avant d’affecter.</Bandeau>
      )}

      <div className={clsx('grid gap-5', !compact && 'xl:grid-cols-2')}>
        <div className="space-y-4">
          {(d.description || d.message) && <p className="whitespace-pre-wrap rounded-2xl bg-surface-douce p-4 text-sm leading-relaxed">{d.description || d.message}</p>}
          <dl className="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
            <Info libelle="Service">{d.service_nom || '—'}</Info>
            <Info libelle="Adresse / repère">{d.adresse || '—'}</Info>
            <Info libelle="Position">{d.latitude != null ? `${d.latitude.toFixed(5)}, ${d.longitude.toFixed(5)}` : 'Indisponible (GPS non fourni)'}</Info>
            <Info libelle="Précision GPS">{d.precision_gps != null ? `± ${Math.round(d.precision_gps)} m` : '—'}</Info>
            <Info libelle="Prise en charge">{d.date_prise_en_charge ? `${dateHeure(d.date_prise_en_charge)} (${duree((new Date(d.date_prise_en_charge) - new Date(d.date_creation)) / 60000)})` : '—'}</Info>
            <Info libelle="Clôture">{d.date_cloture ? dateHeure(d.date_cloture) : '—'}</Info>
            {inter && <Info libelle="Intervenant">{inter.agent_nom || 'Non affecté'}{inter.service_nom ? ` · ${inter.service_nom}` : ''}</Info>}
            {d.motif_cloture && <Info libelle="Motif">{d.motif_cloture}</Info>}
          </dl>

          {d.citoyen_contact && (
            <div className="flex items-center justify-between rounded-2xl border border-surface-bord p-3 text-sm">
              <span><span className="text-texte-doux">Déclarant :</span> <b>{d.citoyen_contact.nom}</b></span>
              {d.citoyen_contact.telephone && <a className="lien inline-flex items-center gap-1" href={`tel:${d.citoyen_contact.telephone}`}><Phone className="h-4 w-4" />{d.citoyen_contact.telephone}</a>}
            </div>
          )}

          {inter?.compte_rendu && (
            <div className="rounded-2xl border border-emerald-200 bg-succes-clair/50 p-4 text-sm">
              <p className="font-semibold text-emerald-900">Compte rendu d’intervention</p>
              <p className="mt-1 whitespace-pre-wrap">{inter.compte_rendu}</p>
              {inter.difficultes && <p className="mt-2 text-emerald-900/80"><b>Difficultés :</b> {inter.difficultes}</p>}
            </div>
          )}

          {d.photos?.length > 0 && <Photos photos={d.photos} />}

          {d.latitude != null && (
            <div className="space-y-2">
              <CarteSenAlert hauteur={220} zoom={15} centre={[d.latitude, d.longitude]} regrouper={false}
                points={[{ id: d.id, lat: d.latitude, lng: d.longitude, couleur: type === 'sos' ? '#E11D48' : STATUTS[s]?.point, sos: type === 'sos' }]} />
              {(role !== 'citoyen') && (
                <a className="lien inline-flex items-center gap-1.5 text-sm" target="_blank" rel="noreferrer"
                  href={`https://www.google.com/maps/dir/?api=1&destination=${d.latitude},${d.longitude}`}>
                  <Navigation className="h-4 w-4" /> Itinéraire (Google Maps) <ExternalLink className="h-3 w-3" />
                </a>
              )}
            </div>
          )}

          {peutGravite && (
            <Champ libelle="Gravité">{(fid) => (
              <Selecteur id={fid} vide={null} valeur={d.gravite} options={Object.entries(GRAVITES).map(([code, g]) => ({ code, libelle: g.libelle }))}
                onChange={(v) => agir('gravite', { gravite: v }, 'Gravité mise à jour.').catch(() => {})} />
            )}</Champ>
          )}
        </div>

        <div>
          <h3 className="mb-3 text-sm font-bold uppercase tracking-wide text-texte-doux">Historique</h3>
          {evs.chargement && !evs.donnees ? <Chargement /> : <Chronologie evenements={evs.donnees || []} />}
          {peutNoter && <NoteRapide onEnvoyer={async (message, visible) => {
            await api(`${chemin(type, id)}note/`, { methode: 'POST', corps: { message, visible_citoyen: visible } });
            evs.recharger(true);
            toast('Note ajoutée.');
          }} />}
        </div>
      </div>

      <Confirmation ouverte={dialogue === 'annuler'} onFermer={() => setDialogue(null)} titre="Annuler le dossier" variante="danger"
        message="Le dossier sera clos avec le statut « Annulé ». Cette action est tracée." motif="Motif de l’annulation" libelleAction="Annuler le dossier"
        onConfirmer={(motif) => agir('annuler', { motif }, 'Dossier annulé.')} />
      <Confirmation ouverte={dialogue === 'rejeter'} onFermer={() => setDialogue(null)} titre="Rejeter le signalement" variante="danger"
        message="À utiliser pour un signalement non fondé ou abusif." motif="Motif du rejet" libelleAction="Rejeter"
        onConfirmer={(motif) => agir('rejeter', { motif }, 'Signalement rejeté.')} />
      <Confirmation ouverte={dialogue === 'decliner'} onFermer={() => setDialogue(null)} titre="Décliner l’affectation"
        message="Le dossier redevient « Nouveau » et le superviseur est prévenu." motif="Raison" libelleAction="Décliner"
        onConfirmer={(motif) => agir('decliner', { motif }, 'Affectation déclinée.')} />
      <DialogueCloture ouverte={dialogue === 'resoudre'} onFermer={() => setDialogue(null)} onValider={(corps) => agir('resoudre', corps, 'Intervention clôturée.')} />
      {dialogue === 'affecter' && <DialogueAffectation dossier={d} onFermer={() => setDialogue(null)} onValider={(corps) => agir('affecter', corps, 'Affectation enregistrée.')} />}
      {dialogue === 'completer' && <DialogueComplement type={type} id={id} onFermer={() => setDialogue(null)} onFait={(maj) => { setDonnees(maj); evs.recharger(true); toast('Complément envoyé.'); }} />}
    </div>
  );
}

function Info({ libelle, children }) {
  return <div><dt className="text-xs text-texte-pale">{libelle}</dt><dd className="font-medium">{children}</dd></div>;
}

export function Chronologie({ evenements }) {
  if (!evenements.length) return <p className="text-sm text-texte-doux">Aucun événement.</p>;
  return (
    <ol className="relative space-y-4 border-l-2 border-surface-bord pl-5">
      {evenements.map((e) => (
        <li key={e.id} className="relative">
          <span className="absolute -left-[27px] top-1 h-3 w-3 rounded-full ring-4 ring-white" style={{ background: STATUTS[e.statut_apres]?.point || '#94A3B8' }} aria-hidden />
          <p className="text-sm font-semibold">
            {e.type === 'transition' ? STATUTS[e.statut_apres]?.libelle : { creation: 'Création', affectation: 'Affectation', complement: 'Complément du citoyen', note: 'Note', gravite: 'Gravité', doublon: 'Doublon potentiel' }[e.type] || e.type}
            {!e.visible_citoyen && <span className="ml-2 rounded bg-slate-100 px-1.5 py-0.5 text-[10px] font-bold uppercase text-slate-500">interne</span>}
          </p>
          {e.message && <p className="text-sm text-texte-doux">{e.message}</p>}
          <p className="text-xs text-texte-pale">{dateHeure(e.date)} · {e.acteur_nom}</p>
        </li>
      ))}
    </ol>
  );
}

function Photos({ photos }) {
  const [urls, setUrls] = useState({});
  useEffect(() => {
    let annule = false;
    const crees = [];
    photos.forEach(async (p) => {
      try {
        const u = await urlObjetProtege(p.url);
        crees.push(u);
        if (!annule) setUrls((x) => ({ ...x, [p.id]: u }));
      } catch { /* photo indisponible */ }
    });
    return () => { annule = true; crees.forEach((u) => URL.revokeObjectURL(u)); };
  }, [photos]);
  return (
    <div className="grid grid-cols-3 gap-2">
      {photos.map((p) => (urls[p.id]
        ? <a key={p.id} href={urls[p.id]} target="_blank" rel="noreferrer"><img src={urls[p.id]} alt="Photo jointe au signalement" className="aspect-square w-full rounded-xl object-cover" /></a>
        : <div key={p.id} className="aspect-square animate-pulse rounded-xl bg-slate-200" />))}
    </div>
  );
}

function NoteRapide({ onEnvoyer }) {
  const [texte, setTexte] = useState('');
  const [visible, setVisible] = useState(false);
  const [envoi, setEnvoi] = useState(false);
  return (
    <form className="mt-5 space-y-2 rounded-2xl border border-surface-bord p-3" onSubmit={async (e) => {
      e.preventDefault();
      if (!texte.trim()) return;
      setEnvoi(true);
      try { await onEnvoyer(texte.trim(), visible); setTexte(''); } finally { setEnvoi(false); }
    }}>
      <textarea className="champ" rows={2} value={texte} onChange={(e) => setTexte(e.target.value)} placeholder="Ajouter une note (difficulté, information utile…)" aria-label="Note" maxLength={2000} />
      <div className="flex items-center justify-between">
        <label className="inline-flex items-center gap-2 text-xs text-texte-doux"><input type="checkbox" checked={visible} onChange={(e) => setVisible(e.target.checked)} /> Visible par le citoyen</label>
        <Bouton taille="sm" type="submit" icone={Send} chargement={envoi} disabled={!texte.trim()}>Ajouter</Bouton>
      </div>
    </form>
  );
}

function DialogueCloture({ ouverte, onFermer, onValider }) {
  const [cr, setCr] = useState('');
  const [diff, setDiff] = useState('');
  const [envoi, setEnvoi] = useState(false);
  return (
    <Fenetre ouverte={ouverte} onFermer={onFermer} titre="Clôturer l’intervention" pied={<>
      <Bouton variante="secondaire" onClick={onFermer}>Annuler</Bouton>
      <Bouton variante="succes" chargement={envoi} disabled={cr.trim().length < 10} onClick={async () => {
        setEnvoi(true);
        try { await onValider({ compte_rendu: cr.trim(), difficultes: diff.trim() }); onFermer(); } catch { /* toast affiché */ } finally { setEnvoi(false); }
      }}>Clôturer comme résolu</Bouton>
    </>}>
      <div className="space-y-4">
        <Champ libelle="Compte rendu" requis aide="Ce qui a été fait, état final. Visible par le citoyen.">{(id) => <textarea id={id} rows={4} className="champ" value={cr} onChange={(e) => setCr(e.target.value)} maxLength={4000} />}</Champ>
        <Champ libelle="Difficultés rencontrées" aide="Interne : non visible par le citoyen.">{(id) => <textarea id={id} rows={2} className="champ" value={diff} onChange={(e) => setDiff(e.target.value)} maxLength={2000} />}</Champ>
      </div>
    </Fenetre>
  );
}

function DialogueAffectation({ dossier, onFermer, onValider }) {
  const config = useConfig();
  const [service, setService] = useState(dossier.service ? String(dossier.service) : '');
  const [agent, setAgent] = useState('');
  const [message, setMessage] = useState('');
  const [envoi, setEnvoi] = useState(false);
  const services = useRessource('/services/');
  const agents = useRessource('/gestion/utilisateurs/', { role: 'agent', is_active: true, service: service || undefined, zone: dossier.region || undefined, taille: 100 });
  const liste = agents.donnees?.results || [];
  return (
    <Fenetre ouverte onFermer={onFermer} titre={`Affecter ${dossier.reference}`} pied={<>
      <Bouton variante="secondaire" onClick={onFermer}>Annuler</Bouton>
      <Bouton chargement={envoi} disabled={!agent} onClick={async () => {
        setEnvoi(true);
        try { await onValider({ agent: Number(agent), service: service ? Number(service) : null, message }); onFermer(); } catch { /* toast */ } finally { setEnvoi(false); }
      }}>Affecter</Bouton>
    </>}>
      <div className="space-y-4">
        <Champ libelle="Service">{(id) => (
          <Selecteur id={id} valeur={service} onChange={(v) => { setService(v); setAgent(''); }} vide="Tous les services"
            options={(services.donnees || []).filter((x) => x.actif).map((x) => ({ code: String(x.id), libelle: x.nom }))} />
        )}</Champ>
        <Champ libelle="Agent" requis aide={`Agents actifs couvrant la région ${config.region(dossier.region)?.libelle || ''}.`}>{(id) => (
          agents.chargement ? <Chargement className="py-3" /> : liste.length === 0
            ? <p id={id} className="rounded-xl bg-alerte-clair p-3 text-sm text-amber-900">Aucun agent actif ne couvre cette zone pour ce service. Créez ou rattachez un agent dans « Utilisateurs ».</p>
            : <Selecteur id={id} valeur={agent} onChange={setAgent} vide="Choisir un agent…"
              options={liste.map((a) => ({ code: String(a.id), libelle: `${a.first_name} ${a.last_name} — ${a.profil_agent?.service_nom || 'sans service'}`.trim() }))} />
        )}</Champ>
        <Champ libelle="Consigne (optionnelle)">{(id) => <textarea id={id} rows={2} className="champ" value={message} onChange={(e) => setMessage(e.target.value)} maxLength={500} />}</Champ>
      </div>
    </Fenetre>
  );
}

function DialogueComplement({ type, id, onFermer, onFait }) {
  const [message, setMessage] = useState('');
  const [photos, setPhotos] = useState([]);
  const [envoi, setEnvoi] = useState(false);
  const [erreur, setErreur] = useState(null);
  return (
    <Fenetre ouverte onFermer={onFermer} titre="Compléter mon signalement" pied={<>
      <Bouton variante="secondaire" onClick={onFermer}>Annuler</Bouton>
      <Bouton chargement={envoi} disabled={!message.trim() && !photos.length} onClick={async () => {
        setEnvoi(true);
        setErreur(null);
        try {
          const fd = new FormData();
          fd.append('message', message.trim());
          photos.forEach((p) => fd.append('photos', p));
          const maj = await api(`${chemin(type, id)}completer/`, { methode: 'POST', corps: fd });
          onFait(maj);
          onFermer();
        } catch (e) { setErreur(e.detail); } finally { setEnvoi(false); }
      }}>Envoyer</Bouton>
    </>}>
      <div className="space-y-4">
        <Champ libelle="Information complémentaire">{(fid) => <textarea id={fid} rows={3} className="champ" value={message} onChange={(e) => setMessage(e.target.value)} maxLength={2000} />}</Champ>
        {type === 'incident' && (
          <label className="flex cursor-pointer items-center gap-2 rounded-xl border border-dashed border-surface-bord p-3 text-sm text-texte-doux hover:bg-surface-douce">
            <ImagePlus className="h-5 w-5" /> {photos.length ? `${photos.length} photo(s) sélectionnée(s)` : 'Ajouter des photos (JPEG, PNG, WEBP · 5 Mo max)'}
            <input type="file" accept="image/jpeg,image/png,image/webp" multiple className="sr-only" onChange={(e) => setPhotos([...e.target.files].slice(0, 5))} />
          </label>
        )}
        {erreur && <Bandeau type="danger">{erreur}</Bandeau>}
        <p className="flex items-center gap-1.5 text-xs text-texte-pale"><MapPin className="h-3.5 w-3.5" /> Les métadonnées des photos (dont la position) sont supprimées par le serveur.</p>
      </div>
    </Fenetre>
  );
}
