import ListeDossiers from '../../components/ListeDossiers';
import { EnTetePage } from '../../components/ui';

export function IncidentsAdmin() {
  return (
    <>
      <EnTetePage titre="Incidents" sousTitre="Tous les signalements : recherche, filtres combinables, affectation, exports." />
      <ListeDossiers type="incident" exports intervalle={30000} />
    </>
  );
}

export function SOSAdmin() {
  return (
    <>
      <EnTetePage titre="Alertes SOS" sousTitre="Alertes géolocalisées des citoyens, à traiter en priorité." />
      <ListeDossiers type="sos" intervalle={15000} filtresVisibles={['q', 'statut', 'region', 'date_debut', 'date_fin', 'actifs']} />
    </>
  );
}
