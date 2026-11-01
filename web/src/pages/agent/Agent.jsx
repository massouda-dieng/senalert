import clsx from 'clsx';
import {
  CheckCircle2, Clock, ExternalLink, Flag, Hourglass, Inbox, MapPin, Navigation, Play, Siren, Timer, X,
} from 'lucide-react';
import { useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { api } from '../../api/client';
import { useRessource } from '../../api/hooks';
import { useAuth } from '../../auth/AuthContext';
import CarteSenAlert, { Legende } from '../../components/Carte';
import { DialogueCloture } from '../../components/DossierDetail';
import ListeDossiers from '../../components/ListeDossiers';
import {
  BadgeGravite, BadgeStatut, Bandeau, Bouton, Carte, Chargement, Confirmation, EnTetePage, EtatErreur, IndicateurSynchro, Indicateur, Onglets, useToast,
} from '../../components/ui';
import { useConfig } from '../../lib/config';
import { GRAVITES, ORDRE_GRAVITE, STATUTS, dateHeure, duree, ilYa, nombre, rangGravite } from '../../lib/format';

const chemin = (d) => (d.sos ? `/alertes/sos/${d.id}/` : `/incidents/${d.id}/`);
const lien = (d) => `/agent/interventions?${d.sos ? 'type=sos&' : ''}dossier=${d.id}`;

/** Fiche de mission : l'essentiel d'un coup d'œil, et l'action suivante sans ouvrir le dossier. */
function Mission({ d, utilisateur, onAgir, onDialogue, enCours }) {
  const estMien = d.intervention?.agent === utilisateur.id;
  const actions = [];
  if (d.statut === 'nouveau') actions.push(<Bouton key="p" taille="sm" icone={CheckCircle2} chargement={enCours} onClick={() => onAgir(d, 'prendre-en-charge', 'Dossier pris en charge.')}>Prendre en charge</Bouton>);
  if (d.statut === 'affecte' && estMien) {
    actions.push(<Bouton key="a" taille="sm" icone={CheckCircle2} chargement={enCours} onClick={() => onAgir(d, 'accepter', 'Mission acceptée.')}>Accepter</Bouton>);
    actions.push(<Bouton key="d" taille="sm" variante="secondaire" icone={X} onClick={() => onDialogue('decliner', d)}>Décliner</Bouton>);
  }
  if (d.statut === 'accepte' && estMien) actions.push(<Bouton key="m" taille="sm" icone={Play} chargement={enCours} onClick={() => onAgir(d, 'demarrer', 'Intervention démarrée.')}>Démarrer</Bouton>);
  if (['accepte', 'en_cours'].includes(d.statut) && estMien) actions.push(<Bouton key="c" taille="sm" variante="succes" icone={Flag} onClick={() => onDialogue('cloturer', d)}>Clôturer</Bouton>);
  return (
    <li className="rounded-2xl border border-l-4 border-surface-bord bg-surface p-3.5 shadow-sm" style={{ borderLeftColor: GRAVITES[d.gravite]?.couleur }}>
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <p className="flex items-center gap-1.5 truncate font-bold">{d.sos && <Siren className="h-4 w-4 shrink-0 text-sos-fonce" aria-hidden />}{d.sos ? 'Alerte SOS' : d.categorie_libelle}</p>
          <Link to={lien(d)} className="font-mono text-xs font-semibold text-marque-700 hover:underline">{d.reference}</Link>
        </div>
        <BadgeGravite gravite={d.gravite} />
      </div>
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

export function TableauAgent() {
  const { utilisateur } = useAuth();
  const config = useConfig();
  const toast = useToast();
  const opts = { intervalle: 20000 };
  const activite = useRessource('/tableau-de-bord/activite-agent/', null, opts);
  const nouveauxInc = useRessource('/incidents/', { statut: 'nouveau', taille: 20 }, opts);
  const nouveauxSos = useRessource('/alertes/sos/', { statut: 'nouveau', taille: 20 }, opts);
  const miensInc = useRessource('/incidents/', { affecte_a_moi: true, actifs: true, taille: 50 }, opts);
  const miensSos = useRessource('/alertes/sos/', { affecte_a_moi: true, actifs: true, taille: 50 }, opts);
  const finisInc = useRessource('/incidents/', { affecte_a_moi: true, statut: 'resolu', taille: 5 }, opts);
  const finisSos = useRessource('/alertes/sos/', { affecte_a_moi: true, statut: 'resolu', taille: 5 }, opts);
  const [action, setAction] = useState(null);
  const [dialogue, setDialogue] = useState(null);

  const toutRecharger = () => [activite, nouveauxInc, nouveauxSos, miensInc, miensSos, finisInc, finisSos].forEach((r) => r.recharger(true));
  const fusion = (sos, inc) => [...(sos.donnees?.results || []).map((d) => ({ ...d, sos: true })), ...(inc.donnees?.results || [])]
    .sort((a, b) => rangGravite(a.gravite) - rangGravite(b.gravite) || Number(b.sos || 0) - Number(a.sos || 0) || new Date(b.date_creation) - new Date(a.date_creation));
  const nouveaux = fusion(nouveauxSos, nouveauxInc);
  const miens = fusion(miensSos, miensInc);
  const ouverts = [...nouveaux, ...miens];
  const attente = miens.filter((d) => d.statut === 'affecte');
  const encours = miens.filter((d) => ['accepte', 'en_cours'].includes(d.statut));
  const finis = fusion(finisSos, finisInc).sort((a, b) => new Date(b.date_cloture) - new Date(a.date_cloture)).slice(0, 5);
  const nbTermines = (activite.donnees?.incidents?.resolus ?? 0) + (activite.donnees?.sos?.resolus ?? 0);
  const profil = utilisateur.profil_agent;
  const a = activite.donnees;
  const erreur = nouveauxInc.erreur || miensInc.erreur;

  const points = useMemo(() => [...nouveaux, ...miens].filter((d) => d.latitude != null).map((d) => ({
    id: `${d.sos ? 's' : 'i'}${d.id}`, lat: d.latitude, lng: d.longitude, sos: d.sos, couleur: GRAVITES[d.gravite]?.couleur || STATUTS[d.statut].point, titre: d.reference,
  })), [nouveauxInc.donnees, nouveauxSos.donnees, miensInc.donnees, miensSos.donnees]); // eslint-disable-line react-hooks/exhaustive-deps

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
      <div className="mb-5 rounded-3xl bg-marque-800 px-5 py-6 text-white sm:px-7">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="min-w-0">
            <p className="text-[13px] font-semibold text-marque-100">Espace agent</p>
            <h1 className="mt-1 font-titre text-2xl font-extrabold sm:text-3xl">{`Bonjour ${utilisateur.first_name || ''}`.trim()}</h1>
            <p className="mt-1 text-sm text-marque-100">{profil ? `${profil.service_nom || 'Service non défini'} · ${(profil.zones || []).map((z) => config.region(z)?.libelle || z).join(', ') || 'aucune zone'}` : ''}</p>
          </div>
          <div className="rounded-lg bg-surface text-texte"><IndicateurSynchro date={miensInc.derniereSynchro} chargement={miensInc.chargement} onRafraichir={toutRecharger} /></div>
        </div>
        <ul className="mt-4 flex flex-wrap gap-2" aria-label="Dossiers ouverts par gravité">
          {ORDRE_GRAVITE.map((g) => (
            <li key={g} className="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-[13px] font-semibold ring-1 ring-white/15">
              <span className="h-2.5 w-2.5 rounded-full" style={{ background: GRAVITES[g].couleur }} aria-hidden />
              {GRAVITES[g].libelle} <span className="tabular-nums">{ouverts.filter((d) => d.gravite === g).length}</span>
            </li>
          ))}
        </ul>
      </div>

      {(!profil?.service_nom || !profil?.zones?.length) && <Bandeau type="alerte" className="mb-5">Votre compte n’est rattaché à aucun service ou zone : vous ne recevrez que les dossiers qui vous sont affectés. Contactez votre superviseur.</Bandeau>}
      {erreur && <div className="mb-5"><EtatErreur erreur={erreur} onReessayer={toutRecharger} /></div>}

      <div className="mb-6 grid grid-cols-2 gap-3 lg:grid-cols-3 xl:grid-cols-5">
        <Indicateur libelle="Nouvelles alertes" valeur={nombre((nouveauxInc.donnees?.count ?? 0) + (nouveauxSos.donnees?.count ?? 0))} icone={Inbox} ton="sos" sous={`dont ${nouveauxSos.donnees?.count ?? 0} SOS`} />
        <Indicateur libelle="En attente" valeur={nombre(attente.length)} icone={Hourglass} ton="alerte" sous="à accepter" />
        <Indicateur libelle="En cours" valeur={nombre(encours.length)} icone={Timer} />
        <Indicateur libelle="Terminées" valeur={nombre(nbTermines)} icone={CheckCircle2} ton="succes" sous={`${a?.resolus_7j ?? 0} sur 7 jours`} />
        <Indicateur libelle="Prise en charge moyenne" valeur={duree(a?.incidents?.delai_moyen_prise_en_charge_min)} icone={Clock} ton="neutre" aide="Vos incidents, de la création à l’acceptation." />
      </div>

      {nouveauxInc.chargement && !nouveauxInc.donnees ? <Chargement /> : (
        <div className="grid gap-4 lg:grid-cols-3">
          <Colonne titre="Nouvelles alertes" icone={Inbox} accent="text-sos-fonce" nombre={nouveaux.length} vide="Aucune nouvelle alerte dans vos zones.">{nouveaux.map(mission)}</Colonne>
          <Colonne titre="En attente d’acceptation" icone={Hourglass} accent="text-alerte" nombre={attente.length} vide="Aucune mission à accepter.">{attente.map(mission)}</Colonne>
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
        message="Le dossier redevient « Nouveau » et le superviseur est prévenu." motif="Raison" libelleAction="Décliner"
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
      <EnTetePage titre="Interventions" sousTitre="Dossiers qui vous sont affectés et nouveaux dossiers de votre service dans vos zones."
        actions={<Onglets actif={type} onChange={(t) => setParams(t === 'sos' ? { type: 'sos' } : {})} onglets={[{ code: 'incident', libelle: 'Incidents', compte: incidents.donnees?.count }, { code: 'sos', libelle: 'SOS', compte: sos.donnees?.count }]} />} />
      <ListeDossiers key={type} type={type} intervalle={20000} vues={VUES_INTERVENTIONS}
        filtresVisibles={['q', 'type_incident', 'region', 'gravite', 'date_debut', 'date_fin']} vide={{ titre: 'Aucun dossier', texte: 'Les dossiers de votre zone apparaîtront ici.' }} />
    </>
  );
}
