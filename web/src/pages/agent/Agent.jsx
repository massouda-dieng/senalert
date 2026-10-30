import { CheckCircle2, ClipboardList, Clock, Flag, Inbox, Siren, Timer } from 'lucide-react';
import { Link, useSearchParams } from 'react-router-dom';
import { useRessource } from '../../api/hooks';
import { useAuth } from '../../auth/AuthContext';
import ListeDossiers from '../../components/ListeDossiers';
import { BadgeGravite, BadgeStatut, Bandeau, Carte, Chargement, EnTetePage, IndicateurSynchro, Indicateur, Onglets } from '../../components/ui';
import Photo from '../../components/Photo';
import { duree, ilYa } from '../../lib/format';

function ListeCourte({ titre, dossiers, vide, type }) {
  return (
    <Carte titre={titre} corpsClassName="p-0">
      {dossiers.length === 0 ? <p className="p-5 text-sm text-texte-doux">{vide}</p> : (
        <ul className="divide-y divide-surface-bord">
          {dossiers.map((d) => (
            <li key={`${d.sos ? 's' : 'i'}${d.id}`}>
              <Link to={`/agent/interventions?${d.sos ? 'type=sos&' : ''}dossier=${d.id}`} className="flex items-center justify-between gap-3 px-5 py-3 hover:bg-surface-douce">
                <div className="min-w-0">
                  <p className="flex items-center gap-2 font-mono text-[13px] font-semibold text-marque-700">
                    {d.sos && <Siren className="h-4 w-4 text-sos" aria-label="SOS" />}{d.reference}
                    {d.en_retard && <Clock className="h-3.5 w-3.5 text-amber-600" aria-label="En retard" />}
                  </p>
                  <p className="truncate text-sm">{d.sos ? 'Alerte SOS' : d.categorie_libelle} · {d.region_libelle} · {ilYa(d.date_creation)}</p>
                </div>
                <div className="flex shrink-0 items-center gap-2"><BadgeGravite gravite={d.gravite} /><BadgeStatut statut={d.statut} /></div>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </Carte>
  );
}

export function TableauAgent() {
  const { utilisateur } = useAuth();
  const opts = { intervalle: 20000 };
  const activite = useRessource('/tableau-de-bord/activite-agent/', null, opts);
  const nouveauxInc = useRessource('/incidents/', { statut: 'nouveau', taille: 10 }, opts);
  const nouveauxSos = useRessource('/alertes/sos/', { statut: 'nouveau', taille: 10 }, opts);
  const miensInc = useRessource('/incidents/', { affecte_a_moi: true, actifs: true, taille: 20 }, opts);
  const miensSos = useRessource('/alertes/sos/', { affecte_a_moi: true, actifs: true, taille: 20 }, opts);
  const profil = utilisateur.profil_agent;
  const nouveaux = [...(nouveauxSos.donnees?.results || []).map((d) => ({ ...d, sos: true })), ...(nouveauxInc.donnees?.results || [])];
  const miens = [...(miensSos.donnees?.results || []).map((d) => ({ ...d, sos: true })), ...(miensInc.donnees?.results || [])];
  const a = activite.donnees;
  const somme = (k) => (a ? (a.incidents[k] || 0) + (a.sos[k] || 0) : '…');

  return (
    <>
      <div className="relative mb-6 overflow-hidden rounded-3xl text-white">
        <Photo nom="pompiers-bnsp" className="absolute inset-0 h-full w-full" alt="" credit={false} />
        <div className="absolute inset-0 bg-gradient-to-r from-black/80 via-black/50 to-black/5" aria-hidden />
        <div className="relative flex flex-wrap items-end justify-between gap-4 px-6 py-8 sm:px-8">
          <div>
            <p className="text-sm font-semibold uppercase tracking-widest text-or">Espace agent</p>
            <h1 className="font-titre text-3xl font-extrabold">Bonjour {utilisateur.first_name || ''}</h1>
            <p className="mt-1 text-white/80">{profil ? `${profil.service_nom || 'Service non défini'} · zones : ${(profil.zones || []).join(', ') || 'aucune'}` : ''}</p>
          </div>
          <div className="rounded-xl bg-surface/90 text-texte"><IndicateurSynchro date={nouveauxInc.derniereSynchro} chargement={nouveauxInc.chargement} onRafraichir={() => { nouveauxInc.recharger(); nouveauxSos.recharger(); miensInc.recharger(); miensSos.recharger(); activite.recharger(); }} /></div>
        </div>
      </div>
      {(!profil?.service_nom || !profil?.zones?.length) && <Bandeau type="alerte" className="mb-5">Votre compte n’est rattaché à aucun service ou zone : vous ne recevrez que les dossiers qui vous sont affectés. Contactez votre superviseur.</Bandeau>}
      <div className="mb-6 grid grid-cols-2 gap-3 lg:grid-cols-5">
        <Indicateur libelle="Nouvelles alertes accessibles" valeur={nouveaux.length} icone={Inbox} ton="sos" />
        <Indicateur libelle="En attente d’acceptation" valeur={somme('en_attente')} icone={Timer} ton="alerte" />
        <Indicateur libelle="En cours" valeur={somme('en_cours')} icone={ClipboardList} />
        <Indicateur libelle="Résolues (7 jours)" valeur={a?.resolus_7j ?? '…'} icone={CheckCircle2} ton="succes" />
        <Indicateur libelle="Délai moyen de prise en charge" valeur={duree(a?.incidents?.delai_moyen_prise_en_charge_min)} icone={Flag} ton="neutre" aide="Incidents qui vous ont été confiés" />
      </div>
      <div className="grid gap-5 xl:grid-cols-2">
        {miensInc.chargement && !miensInc.donnees ? <Chargement /> : <ListeCourte titre="Mes interventions en cours" dossiers={miens} vide="Aucune intervention active." />}
        {nouveauxInc.chargement && !nouveauxInc.donnees ? <Chargement /> : <ListeCourte titre="Nouvelles alertes de ma zone" dossiers={nouveaux} vide="Aucune nouvelle alerte dans vos zones." />}
      </div>
    </>
  );
}

export function Interventions() {
  const [params, setParams] = useSearchParams();
  const type = params.get('type') === 'sos' ? 'sos' : 'incident';
  return (
    <>
      <EnTetePage titre="Interventions" sousTitre="Dossiers qui vous sont affectés et nouveaux dossiers de votre service dans vos zones."
        actions={<Onglets actif={type} onChange={(t) => setParams(t === 'sos' ? { type: 'sos' } : {})} onglets={[{ code: 'incident', libelle: 'Incidents' }, { code: 'sos', libelle: 'SOS' }]} />} />
      <ListeDossiers key={type} type={type} intervalle={20000}
        filtresVisibles={['q', 'statut', 'type_incident', 'region', 'gravite', 'date_debut', 'date_fin', 'affecte_a_moi', 'actifs']}
        filtresParDefaut={{ actifs: 'true' }} vide={{ titre: 'Aucun dossier', texte: 'Les dossiers de votre zone apparaîtront ici.' }} />
    </>
  );
}
