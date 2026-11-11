import clsx from 'clsx';
import {
  CheckCircle2, Clock, ExternalLink, Flag, Hourglass, MapPin, Navigation, Play, Power, Siren, Timer, X,
} from 'lucide-react';
import { useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { api } from '../../api/client';
import { useRessource } from '../../api/hooks';
import { useAuth } from '../../auth/AuthContext';
import CarteSenAlert, { Legende } from '../../components/Carte';
import Photo from '../../components/Photo';
import { PHOTO_CATEGORIE } from '../../lib/photos';
import { DialogueCloture } from '../../components/DossierDetail';
import ListeDossiers from '../../components/ListeDossiers';
import {
  BadgeGravite, BadgeStatut, Bandeau, Bouton, Carte, Chargement, Confirmation, EnTetePage, EtatErreur, IndicateurSynchro, Indicateur, Onglets, useToast,
} from '../../components/ui';
import { GRAVITES, ORDRE_GRAVITE, STATUTS, dateHeure, ilYa, nombre, rangGravite } from '../../lib/format';

const chemin = (d) => (d.sos ? `/alertes/sos/${d.id}/` : `/incidents/${d.id}/`);
const lien = (d) => `/agent/interventions?${d.sos ? 'type=sos&' : ''}dossier=${d.id}`;

/** Fiche de mission : l'essentiel d'un coup d'œil, et l'action suivante sans ouvrir le dossier. */
function Mission({ d, utilisateur, onAgir, onDialogue, enCours }) {
  const estMien = d.intervention?.agent === utilisateur.id;
  const actions = [];
  if (d.statut === 'affecte' && estMien) {
    actions.push(<Bouton key="a" taille="sm" icone={CheckCircle2} chargement={enCours} onClick={() => onAgir(d, 'accepter', 'Mission prise en charge.')}>Prendre en charge</Bouton>);
    actions.push(<Bouton key="d" taille="sm" variante="secondaire" icone={X} onClick={() => onDialogue('decliner', d)}>Décliner</Bouton>);
  }
  if (d.statut === 'accepte' && estMien) actions.push(<Bouton key="m" taille="sm" icone={Play} chargement={enCours} onClick={() => onAgir(d, 'demarrer', 'Intervention démarrée.')}>Démarrer</Bouton>);
  if (['accepte', 'en_cours'].includes(d.statut) && estMien) actions.push(<Bouton key="c" taille="sm" variante="succes" icone={Flag} onClick={() => onDialogue('cloturer', d)}>Clôturer</Bouton>);
  return (
    <li className="overflow-hidden rounded-2xl border border-surface-bord bg-surface shadow-sm">
      <div className="flex gap-3 p-3.5">
        {d.sos ? (
          <span className="grid h-16 w-20 shrink-0 place-items-center rounded-xl bg-sos-fonce text-white"><Siren className="h-7 w-7" aria-hidden /></span>
        ) : (
          <Photo nom={PHOTO_CATEGORIE[d.type_incident] || 'dakar-vue'} className="h-16 w-20 shrink-0 rounded-xl" alt="" credit={false} />
        )}
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-2">
            <p className="truncate font-bold">{d.sos ? `Alerte SOS${d.type_urgence_libelle && d.type_urgence !== 'non_precise' ? ` · ${d.type_urgence_libelle}` : ''}` : d.categorie_libelle}</p>
            <BadgeGravite gravite={d.gravite} />
          </div>
          <Link to={lien(d)} className="font-mono text-xs font-semibold text-marque-700 hover:underline">{d.reference}</Link>
        </div>
      </div>
      <div className="px-3.5 pb-3.5">
      <p className="mt-2 flex items-center gap-1.5 text-[13px] text-texte-doux"><MapPin className="h-3.5 w-3.5 shrink-0" aria-hidden /><span className="truncate">{d.adresse || d.region_libelle || 'Lieu non précisé'}</span></p>
      <p className="mt-0.5 flex items-center gap-1.5 text-[13px] text-texte-doux" title={dateHeure(d.date_creation)}>
        <Clock className="h-3.5 w-3.5 shrink-0" aria-hidden />{ilYa(d.date_creation)}
        {d.en_retard && <span className="font-semibold text-alerte">· en retard</span>}
      </p>
      <div className="mt-3 flex flex-wrap items-center gap-2">
        {actions}
        {d.latitude != null && (
          <a target="_blank" rel="noreferrer" href={`https://www.google.com/maps/dir/?api=1&destination=${d.latitude},${d.longitude}`} aria-label={`Itinéraire vers ${d.reference}`}
            className="inline-flex items-center gap-1 rounded-xl px-2 py-1.5 text-[13px] font-semibold text-marque-700 hover:bg-marque-50">
            <Navigation className="h-3.5 w-3.5" aria-hidden /> Itinéraire <ExternalLink className="h-3 w-3" aria-hidden />
          </a>
        )}
      </div>
      </div>
    </li>
  );
}

function Colonne({ titre, icone: Icone, nombre: n, vide, children, accent }) {
  return (
    <section className="flex min-w-0 flex-col rounded-2xl bg-surface-douce p-3 ring-1 ring-surface-bord" aria-label={titre}>
      <header className="mb-3 flex items-center gap-2 px-1">
        <Icone className={clsx('h-4 w-4', accent || 'text-marque-600')} aria-hidden />
        <h2 className="text-sm font-bold">{titre}</h2>
        <span className="ml-auto rounded-full bg-surface px-2 py-0.5 text-xs font-bold tabular-nums ring-1 ring-surface-bord">{n}</span>
      </header>
      {n === 0 ? <p className="px-1 pb-2 text-sm text-texte-doux">{vide}</p> : <ul className="max-h-[560px] space-y-3 overflow-y-auto pr-0.5">{children}</ul>}
    </section>
  );
}

/** L'agent se déclare disponible ou non : son superviseur le voit avant de lui affecter un dossier. */
function Disponibilite() {
  const { utilisateur, setUtilisateur } = useAuth();
  const toast = useToast();
  const [envoi, setEnvoi] = useState(false);
  const disponible = utilisateur.profil_agent?.disponible ?? true;
  return (
    <Bouton taille="sm" variante={disponible ? 'succes' : 'secondaire'} icone={Power} chargement={envoi} aria-pressed={disponible}
      title="Votre superviseur voit si vous êtes disponible avant de vous affecter un dossier."
      onClick={async () => {
        setEnvoi(true);
        try {
          setUtilisateur(await api('/auth/disponibilite/', { methode: 'POST', corps: { disponible: !disponible } }));
          toast(disponible ? 'Vous êtes indisponible : votre superviseur le voit avant de vous affecter un dossier.' : 'Vous êtes disponible.');
        } catch (e) { toast(e.detail, 'erreur'); } finally { setEnvoi(false); }
      }}>
      {disponible ? 'Disponible' : 'Indisponible'}
    </Bouton>
  );
}

export function TableauAgent() {
  const { utilisateur } = useAuth();
  const toast = useToast();
  const opts = { intervalle: 20000 };
  const activite = useRessource('/tableau-de-bord/activite-agent/', null, opts);
  const miensInc = useRessource('/incidents/', { affecte_a_moi: true, actifs: true, taille: 50 }, opts);
  const miensSos = useRessource('/alertes/sos/', { affecte_a_moi: true, actifs: true, taille: 50 }, opts);
  const finisInc = useRessource('/incidents/', { affecte_a_moi: true, statut: 'resolu', taille: 5 }, opts);
  const finisSos = useRessource('/alertes/sos/', { affecte_a_moi: true, statut: 'resolu', taille: 5 }, opts);
  const [action, setAction] = useState(null);
  const [dialogue, setDialogue] = useState(null);

  const toutRecharger = () => [activite, miensInc, miensSos, finisInc, finisSos].forEach((r) => r.recharger(true));
  const fusion = (sos, inc) => [...(sos.donnees?.results || []).map((d) => ({ ...d, sos: true })), ...(inc.donnees?.results || [])]
    .sort((a, b) => rangGravite(a.gravite) - rangGravite(b.gravite) || Number(b.sos || 0) - Number(a.sos || 0) || new Date(b.date_creation) - new Date(a.date_creation));
  // L'agent ne voit que les dossiers qui lui sont transmis (choisi par le citoyen ou par son superviseur).
  const miens = fusion(miensSos, miensInc);
  const attente = miens.filter((d) => d.statut === 'affecte');
  const encours = miens.filter((d) => ['accepte', 'en_cours'].includes(d.statut));
  const finis = fusion(finisSos, finisInc).sort((a, b) => new Date(b.date_cloture) - new Date(a.date_cloture)).slice(0, 5);
  const nbTermines = (activite.donnees?.incidents?.resolus ?? 0) + (activite.donnees?.sos?.resolus ?? 0);
  const a = activite.donnees;
  const erreur = miensInc.erreur;

  const points = useMemo(() => miens.filter((d) => d.latitude != null).map((d) => ({
    id: `${d.sos ? 's' : 'i'}${d.id}`, lat: d.latitude, lng: d.longitude, sos: d.sos, type: d.type_incident, couleur: GRAVITES[d.gravite]?.couleur || STATUTS[d.statut].point, titre: d.reference,
  })), [miensInc.donnees, miensSos.donnees]); // eslint-disable-line react-hooks/exhaustive-deps

  const agir = async (d, verbe, message, corps) => {
    setAction(`${d.sos ? 's' : 'i'}${d.id}`);
    try {
      await api(`${chemin(d)}${verbe}/`, { methode: 'POST', corps });
      toast(message);
    } catch (e) {
      toast(e.detail, 'erreur');
      throw e;
    } finally {
      setAction(null);
      toutRecharger();
    }
  };
  const mission = (d) => (
    <Mission key={`${d.sos ? 's' : 'i'}${d.id}`} d={d} utilisateur={utilisateur} enCours={action === `${d.sos ? 's' : 'i'}${d.id}`}
      onAgir={(x, v, m) => agir(x, v, m).catch(() => {})} onDialogue={(type, x) => setDialogue({ type, d: x })} />
  );

  return (
    <>
      <div className="relative mb-5 overflow-hidden rounded-3xl text-white">
        <Photo nom="pompiers-bnsp" className="absolute inset-0 h-full w-full" alt="" credit={false} priorite />
        <div className="absolute inset-0 bg-gradient-to-r from-marque-950/90 via-marque-900/75 to-marque-900/30" aria-hidden />
        <div className="relative flex flex-wrap items-end justify-between gap-4 px-5 py-7 sm:px-8">
          <div className="min-w-0">
            <p className="text-[13px] font-semibold uppercase tracking-wider text-marque-100">Espace agent</p>
            <h1 className="mt-1 font-titre text-2xl font-extrabold sm:text-3xl">{`Bonjour ${utilisateur.first_name || ''}`.trim()}</h1>
            <p className="mt-1 text-sm text-white/85">{[utilisateur.profil_agent?.fonction, utilisateur.structure_nom].filter(Boolean).join(' · ')}</p>
            <p className="mt-3 text-sm text-white/85">
              {attente.length ? `${attente.length} mission(s) à prendre en charge` : encours.length ? `${encours.length} intervention(s) en cours` : 'Aucune mission en attente'}
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Disponibilite />
            <div className="rounded-lg bg-surface text-texte"><IndicateurSynchro date={miensInc.derniereSynchro} chargement={miensInc.chargement} onRafraichir={toutRecharger} /></div>
          </div>
        </div>
      </div>

      {!utilisateur.structure && <Bandeau type="alerte" className="mb-5">Votre compte n’est rattaché à aucune structure : aucun dossier ne peut vous être affecté. Contactez votre superviseur.</Bandeau>}
      {erreur && <div className="mb-5"><EtatErreur erreur={erreur} onReessayer={toutRecharger} /></div>}

      <div className="mb-6 grid grid-cols-3 gap-3">
        <Indicateur libelle="À prendre en charge" valeur={nombre(attente.length)} icone={Hourglass} ton="sos" sous={attente.some((d) => d.sos) ? `dont ${attente.filter((d) => d.sos).length} SOS` : undefined} />
        <Indicateur libelle="En cours" valeur={nombre(encours.length)} icone={Timer} />
        <Indicateur libelle="Terminées" valeur={nombre(nbTermines)} icone={CheckCircle2} ton="succes" sous={`${a?.resolus_7j ?? 0} sur 7 jours`} />
      </div>

      {miensInc.chargement && !miensInc.donnees ? <Chargement /> : (
        <div className="grid gap-4 lg:grid-cols-2">
          <Colonne titre="À prendre en charge" icone={Hourglass} accent="text-sos-fonce" nombre={attente.length} vide="Aucune mission reçue. Votre superviseur vous affecte les dossiers de votre structure.">{attente.map(mission)}</Colonne>
          <Colonne titre="Interventions en cours" icone={Timer} nombre={encours.length} vide="Aucune intervention en cours.">{encours.map(mission)}</Colonne>
        </div>
      )}

      <div className="mt-6 grid gap-5 xl:grid-cols-[1.4fr_1fr]">
        <Carte titre="Carte des interventions" action={<Link to="/agent/carte" className="lien text-sm">Carte complète</Link>} corpsClassName="p-3">
          <CarteSenAlert points={points} hauteur={340} zoom={7} cadrer={points.length > 0} />
          <div className="mt-2 px-1"><Legende elements={ORDRE_GRAVITE.map((g) => ({ libelle: GRAVITES[g].libelle, couleur: GRAVITES[g].couleur }))} /></div>
        </Carte>
        <Carte titre="Historique récent" action={<Link to="/agent/interventions?vue=historique" className="lien text-sm">Tout l’historique</Link>} corpsClassName="p-0">
          {finis.length === 0 ? <p className="p-5 text-sm text-texte-doux">Aucune intervention terminée pour l’instant.</p> : (
            <ul className="divide-y divide-surface-bord">
              {finis.map((d) => (
                <li key={`${d.sos ? 's' : 'i'}${d.id}`}>
                  <Link to={lien(d)} className="flex items-center justify-between gap-3 px-5 py-3 hover:bg-surface-douce">
                    <div className="min-w-0">
                      <p className="truncate text-sm font-semibold">{d.sos ? 'Alerte SOS' : d.categorie_libelle}</p>
                      <p className="truncate text-xs text-texte-doux"><span className="font-mono">{d.reference}</span> · {ilYa(d.date_cloture)}</p>
                    </div>
                    <BadgeStatut statut={d.statut} />
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </Carte>
      </div>

      <Confirmation ouverte={dialogue?.type === 'decliner'} onFermer={() => setDialogue(null)} titre="Décliner la mission"
        message="Le dossier redevient « Nouveau » et votre superviseur est prévenu." motif="Raison" libelleAction="Décliner"
        onConfirmer={(motif) => agir(dialogue.d, 'decliner', 'Mission déclinée.', { motif })} />
      <DialogueCloture ouverte={dialogue?.type === 'cloturer'} onFermer={() => setDialogue(null)}
        onValider={(corps) => agir(dialogue.d, 'resoudre', 'Intervention clôturée.', corps)} />
    </>
  );
}

const VUES_INTERVENTIONS = [
  { code: 'ouverts', libelle: 'Ouverts', filtres: { actifs: 'true' } },
  { code: 'miens', libelle: 'Mes interventions', filtres: { actifs: 'true', affecte_a_moi: 'true' } },
  { code: 'historique', libelle: 'Historique', filtres: { affecte_a_moi: 'true', statut: 'resolu' } },
  { code: 'tous', libelle: 'Tous', filtres: {} },
];

export function Interventions() {
  const [params, setParams] = useSearchParams();
  const type = params.get('type') === 'sos' ? 'sos' : 'incident';
  const incidents = useRessource('/incidents/', { actifs: true, taille: 1 }, { intervalle: 20000 });
  const sos = useRessource('/alertes/sos/', { actifs: true, taille: 1 }, { intervalle: 20000 });
  return (
    <>
      <EnTetePage titre="Interventions" sousTitre="Dossiers que votre superviseur vous a affectés."
        actions={<Onglets actif={type} onChange={(t) => setParams(t === 'sos' ? { type: 'sos' } : {})} onglets={[{ code: 'incident', libelle: 'Incidents', compte: incidents.donnees?.count }, { code: 'sos', libelle: 'SOS', compte: sos.donnees?.count }]} />} />
      <ListeDossiers key={type} type={type} intervalle={20000} vues={VUES_INTERVENTIONS}
        filtresVisibles={['q', 'type_incident', 'region', 'gravite', 'date_debut', 'date_fin']} vide={{ titre: 'Aucun dossier', texte: 'Les dossiers de votre zone apparaîtront ici.' }} />
    </>
  );
}
